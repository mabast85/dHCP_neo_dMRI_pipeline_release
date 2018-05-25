#!/bin/bash


set -e
echo -e "\n START: Setting up jobs for the dHCP neonatal dMRI data processing pipeline"


if [ "$9" == "" ];then
    echo "The script will queue all the jobs necessary to process dHCP neonatal dMRI data"
    echo ""
    echo "usage: $0 <data folder> <session folder> <data file> <connectome ID> <acquisition protocol> <readout time> <output folder> <age at scan> <age at birth> <no. sessions>"
    echo ""
    echo "       data folder: path where the session data is stored"
    echo "       session folder: session folder name"
    echo "       data file: raw data file name"
    echo "       connectome ID: connectome ID number (CC...)"
    echo "       acquisition protocol: name of the text file containing gradient orientations, b-values and phase encoding directions"
    echo "       output folder: folder where results will be stored"
    echo "       age at scan: in weeks (GA)"
    echo "       age at birth: in weeks (GA)"
    echo "       no. sessions: number of sessions"
    echo ""
    echo ""
    exit 1
fi

dataFolder=$1          # Path to data folder
sessionFolder=$2       # Session number
dataFile=$3	       # FileName to avoid confusion...
connID=$4              # Unique connectome ID
acqProt=$5             # Acquisition protocol file
outFolder=$6           # Path where the processed subjects will be stored
ageScan=$7             # Age at scan (w GA)
ageBirth=$8            # Age at birth (w GA)
nSessions=$9           # Number of sessions

noB0s=2                # Number of B0 volumes for each PE direction used to estimate distortions with TOPUP


#============================================================================
# Check for scan completeness
#============================================================================
dimt4=`${FSLDIR}/bin/fslval ${dataFolder}/${sessionFolder}/DWI/${dataFile} dim4`
complete_check=${dimt4}
usable_check=1
if [ $dimt4 -lt 34 ]; then
    echo "WARNING: The dataset is unusable as it does not contain enough B0 volumes"
    SubjFolder=/vols/Data/baby/DMRI_pipeline_testing/unusable_"$ConnID"
    mkdir -p ${SubjFolder}
    usable_check=0
    exit 1
elif [ $dimt4 -lt 123 ]; then
    echo "WARNING: The dataset is incomplete and does not contain enough B0 pairs for each PE direction"
    noB0s=1
    usable_check=1
fi


#============================================================================
# Create directory structure and write ages
#============================================================================
subjOutFolder=${outFolder}/${connID}/${sessionFolder}

prepFolder=${subjOutFolder}/PreProcessed
anatFolder=${subjOutFolder}/T2w
diffFolder=${subjOutFolder}/Diffusion

mkdir -p ${prepFolder}/topup
mkdir -p ${prepFolder}/eddy
mkdir -p ${prepFolder}/tmpData
mkdir -p ${anatFolder}
mkdir -p ${diffFolder}

echo `awk -v v="$ageScan" 'BEGIN{printf "%.0f", v}'` > ${subjOutFolder}/age
echo `awk -v v="$ageBirth" 'BEGIN{printf "%.0f", v}'` > ${subjOutFolder}/birth


#============================================================================
# Store QC information
#============================================================================
echo "{" > ${subjOutFolder}/initQC.json
echo "   \"Complete\": ${complete_check}," >> ${subjOutFolder}/initQC.json
echo "   \"Usable\": ${usable_check}," >> ${subjOutFolder}/initQC.json
echo "   \"nSessions\": ${nSessions}," >> ${subjOutFolder}/initQC.json
echo "   \"birthAge\": ${ageBirth}," >> ${subjOutFolder}/initQC.json
echo "   \"scanAge\": ${ageScan}" >> ${subjOutFolder}/initQC.json
echo "}" >> ${subjOutFolder}/initQC.json


#============================================================================
# Prepare super-resolution commands
#============================================================================
${scriptsFolder}/superres/setup_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz ${prepFolder}/eddy/nodif_brain_mask.nii.gz ${prepFolder}/eddy/sr_commands.txt ${dimt4}


#============================================================================
# Set main chain starting from last completed step
#============================================================================
if [ ! -e ${prepFolder}/eddy/eddy_corrected.nii.gz ]; then
    
    #============================================================================
    # Import files and create initial structure
    #============================================================================
    importid=`${FSLDIR}/bin/fsl_sub -q short.q -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_importFiles.sh ${dataFolder}/${sessionFolder}/DWI ${dataFile} ${prepFolder} ${acqProt} ${dimt4} ${noB0s}`

    #============================================================================
    # Run TOPUP
    #============================================================================
    topupid=`${FSLDIR}/bin/fsl_sub -q short.q -j ${importid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runTopup.sh ${prepFolder}/topup`
    
    #============================================================================
    # EDDY run with outlier detection and replacemetn, s2v and no masking of out-of-FOV voxels
    #============================================================================
    eddyid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${topupid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runEddy.sh ${prepFolder} ${prepFolder}/tmpData/data`
    
    #============================================================================
    # Super resolution for EDDY corrected data
    #============================================================================
    pre_srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${eddyid} -l ${prepFolder}/logs ${scriptsFolder}/superres/prerun_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz`

    srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pre_srid} -l ${prepFolder}/logs -t ${prepFolder}/eddy/sr_commands.txt`
    
    post_srid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${srid} -l ${prepFolder}/logs ${scriptsFolder}/superres/postrun_superres.sh ${prepFolder}/eddy/eddy_corrected.nii.gz`

    #============================================================================
    # Run EDDY post processing steps and DT fit
    #============================================================================
    pprocid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${post_srid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runPostProc.sh ${prepFolder} ${diffFolder} 1`

    #============================================================================
    # Run BPX model 3
    #============================================================================
    bpxid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`

    #============================================================================
    # Coregister DWI with Structural T2 (native and template spaces)
    #============================================================================
    regid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runRegistration.sh ${anatFolder} ${subjOutFolder} ${t2Folder} ${segFolder} ${surfFolder} ${dofsFolder}`
    
    #============================================================================
    # Generate PNGs for QC reports
    #============================================================================
    pngid=`${FSLDIR}/bin/fsl_sub -q short.q -j ${regid} -l ${prepFolder}/logs ${scriptsFolder}/utils/generateFigs.sh ${subjOutFolder}`
    
else

    #============================================================================
    # Run EDDY post processing steps
    #============================================================================
    pprocid=`${FSLDIR}/bin/fsl_sub -q cuda.q -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runPostProc.sh ${prepFolder} ${diffFolder} 1`
    
    #============================================================================
    # Run BPX model 3
    #============================================================================
    bpxid=`${FSLDIR}/bin/fsl_sub -q cuda.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runBPX.sh ${diffFolder}`

    #============================================================================
    # Coregister DWI with Structural T2 (native and template spaces)
    #============================================================================
    regid=`${FSLDIR}/bin/fsl_sub -q long.q -j ${pprocid} -l ${prepFolder}/logs ${scriptsFolder}/dHCP_neo_dMRI_runRegistration.sh ${anatFolder} ${subjOutFolder} ${t2Folder} ${segFolder} ${surfFolder} ${dofsFolder}`

    #============================================================================
    # Generate PNGs for QC reports
    #============================================================================
    pngid=`${FSLDIR}/bin/fsl_sub -q short.q -j ${regid} -l ${prepFolder}/logs ${scriptsFolder}/utils/generateFigs.sh ${subjOutFolder}`
    
fi

echo -e "\n END: Setting up jobs for the dHCP neonatal dMRI data processing pipeline"
