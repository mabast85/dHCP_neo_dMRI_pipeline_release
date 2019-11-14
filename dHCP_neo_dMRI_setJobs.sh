#!/bin/bash


set -e
echo -e "\n START: Setting up jobs for the dHCP neonatal dMRI data processing pipeline"


if [ "${12}" == "" ];then
    echo "The script will queue all the jobs necessary to process dHCP neonatal dMRI data"
    echo ""
    echo "usage: $0 <data folder> <session folder> <data file> <connectome ID> <acquisition protocol> <slspec> <output folder> <age at scan> <age at birth> <subject T2> <subject segmentation> <superres flag> <gpu flag>"
    echo ""
    echo "       data folder: path where the session data is stored"
    echo "       session folder: session folder name"
    echo "       data file: raw data file name"
    echo "       connectome ID: subject's connectome ID"
    echo "       acquisition protocol: name of the text file containing gradient orientations, b-values and phase encoding directions"
    echo "       slspec: eddy slspec file specifying the slice acquisition order (0 if not available)"
    echo "       output folder: folder where results will be stored"
    echo "       age at scan: PMA in weeks at scan (rounded)"
    echo "       age at birth: PMA in weeks at birth (rounded)"
    echo "       subject T2: subject's anatomical T2-weighted volume"
    echo "       subject segmentation: Subject's tissue segmentation from dHCP structural pipeline (in T2-w space)"
    echo "       superres flag: 0=do not use super resolution algorithm, 1=use super resolution algorithm"
    echo "       gpu flag: 0=do not use NVIDIA GPU acceleration, 1=use NVIDIA GPU acceleration"
    echo ""
    echo ""
    exit 1
fi

dataFolder=$1          # Path to data folder
sessionFolder=$2       # Session number
dataFile=$3	           # FileName to avoid confusion...
connID=$4              # Unique connectome ID
acqProt=$5             # Acquisition protocol file
slspec=$6              # Eddy slspec file (0 if not available)
outFolder=$7           # Path where the processed subjects will be stored
ageScan=$8             # PMA age at scan (rounded)
ageBirth=$9            # Age at birth (w GA)
subjT2=${10}           # Subject's anatomical T2-weighted scan
subjSeg=${11}          # Subject's tissue segmentation (in T2-w space)
srFlag=${12}           # Superres flag
gpuFlag=${13}          # GPU flag

noB0s=2                # Number of B0 volumes for each PE direction used to estimate distortions with TOPUP
dimt4=`${FSLDIR}/bin/fslval ${dataFolder}/${sessionFolder}/DWI/${dataFile} dim4` # Number of acquired volumes


#============================================================================
# Create directory structure and write ages
#============================================================================
subjOutFolder=${outFolder}/${connID}/${sessionFolder}

prepFolder=${subjOutFolder}/PreProcessed
anatFolder=${subjOutFolder}/T2w
diffFolder=${subjOutFolder}/Diffusion
rawFolder=${subjOutFolder}/raw

mkdir -p ${prepFolder}/topup
mkdir -p ${prepFolder}/eddy
mkdir -p ${anatFolder}
mkdir -p ${diffFolder}
mkdir -p ${rawFolder}

echo "${ageScan}" > ${subjOutFolder}/age
echo "${ageBirth}"  > ${subjOutFolder}/birth


#============================================================================
# Prepare super-resolution commands (if needed)
#============================================================================
if [ "${srFlag}" -eq "1" ]; then
    ${scriptsFolder}/superres/setup_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz ${prepFolder}/eddy/nodif_brain_mask.nii.gz ${prepFolder}/eddy/sr_commands.txt ${dimt4}
fi


#============================================================================
# Set main chain starting from last completed step
#============================================================================
if [ ! -e ${prepFolder}/eddy/eddy_corrected.nii.gz ]; then
    
    #============================================================================
    # Import files and create initial structure
    #============================================================================
    importid=`${FSLDIR}/bin/fsl_sub -q long.q -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_importFiles.sh ${dataFolder}/${sessionFolder}/DWI ${dataFile} ${subjOutFolder} ${acqProt} ${dimt4} ${noB0s}`
    
    #============================================================================
    # Run TOPUP
    #============================================================================
    topupid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${importid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runTopup.sh ${subjOutFolder}`

    #============================================================================
    # Run EDDY
    #============================================================================
    if [ "${gpuFlag}" -eq "1" ]; then
	eddyid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${topupid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runEddy.sh ${subjOutFolder} ${slspec} ${gpuFlag}`
    else
	eddyid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${topupid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runEddy.sh ${subjOutFolder} ${slspec} ${gpuFlag}`
    fi
    
    #============================================================================
    # Super resolution for EDDY corrected data (if needed)
    #============================================================================
    if [ "${srFlag}" -eq "1" ]; then
        pre_srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${eddyid} -l ${prepFolder}/logs ${scriptsFolder}/superres/prerun_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz`

        srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pre_srid} -l ${prepFolder}/logs -t ${prepFolder}/eddy/sr_commands.txt`
    
        post_srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${srid} -l ${prepFolder}/logs ${scriptsFolder}/superres/postrun_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz`
    else
        post_srid=${eddyid}
    fi

    #============================================================================
    # Run EDDY post processing steps and DT fit
    #============================================================================
    pprocid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${post_srid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runPostProc.sh ${subjOutFolder} ${srFlag} 1`

    #============================================================================
    # Run BPX model 3
    #============================================================================
    if [ "${gpuFlag}" -eq "1" ]; then
	bpxid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`
    else
	bpxid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`
    fi

    #============================================================================
    # Extract tissue and brain masks from segmented volume
    #============================================================================
    maskid=`${FSLDIR}/bin/fsl_sub -q veryshort.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_getMasks.sh ${subjOutFolder} ${subjSeg}`
    
    #============================================================================
    # Register diffusion to structural T2 (native and template spaces)
    #============================================================================
    regid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${maskid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runRegistration.sh ${subjOutFolder} ${subjT2} ${anatFolder}/segmentation/wm_mask.nii.gz 1`
    
    #============================================================================
    # Generate PNGs for QC reports
    #============================================================================
    pngid=`${FSLDIR}/bin/fsl_sub -q short.q -j ${regid} -l ${prepFolder}/logs ${scriptsFolder}/utils/generateFigs.sh ${subjOutFolder}`
    
else

    #============================================================================
    # Run EDDY post processing steps and DT fit
    #============================================================================
    pprocid=`${FSLDIR}/bin/fsl_sub -q long.q -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runPostProc.sh ${subjOutFolder} ${srFlag} 1`
    
    #============================================================================
    # Run BPX model 3
    #============================================================================
    if [ "${gpuFlag}" -eq "1" ]; then
	bpxid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`
    else
	bpxid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`
    fi
    
    #============================================================================
    # Extract tissue and brain masks from segmented volume
    #============================================================================
    maskid=`${FSLDIR}/bin/fsl_sub -q veryshort.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_getMasks.sh ${subjOutFolder} ${subjSeg}`
    
    #============================================================================
    # Coregister DWI with Structural T2 (native and template spaces)
    #============================================================================
    regid=`${FSLDIR}/bin/fsl_sub -q long.q -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runRegistration.sh ${subjOutFolder} ${subjT2} ${anatFolder}/segmentation/wm_mask.nii.gz 1`
    
    #============================================================================
    # Generate PNGs for QC reports
    #============================================================================
    pngid=`${FSLDIR}/bin/fsl_sub -q short.q -j ${regid} -l ${prepFolder}/logs ${scriptsFolder}/utils/generateFigs.sh ${subjOutFolder}`
    
fi

echo -e "\n END: Setting up jobs for the dHCP neonatal dMRI data processing pipeline"
