#!/bin/bash
set -e
echo -e "\n START: runPostProc"


subFolder=$1
srFlag=$2
qcFlag=$3

rawFolder=${subFolder}/raw
prepFolder=${subFolder}/PreProcessed
eddyFolder=${prepFolder}/eddy
diffFolder=${subFolder}/Diffusion

if [ "${qcFlag}" -eq "1" ]; then
    mkdir -p ${prepFolder}/QC
fi
mkdir -p ${diffFolder}


#============================================================================
# Remove negative intensity values (caused by spline interpolation) from 
# pre-processed data. Copy bvals and (rotated) bvecs to the Diffusion folder.
#============================================================================
if [ "${srFlag}" -eq "1" ]; then
    ${FSLDIR}/bin/fslmaths ${eddyFolder}/data_sr -thr 0 ${diffFolder}/data
    rm ${eddyFolder}/data_sr.*
else
    ${FSLDIR}/bin/fslmaths ${eddyFolder}/eddy_corrected -thr 0 ${diffFolder}/data
fi
cp ${rawFolder}/bvals ${diffFolder}/bvals
cp ${eddyFolder}/eddy_corrected.eddy_rotated_bvecs ${diffFolder}/bvecs


#============================================================================
# Get the brain mask using BET, average shell data and attenuation profiles.
# Fit diffusion tensor to each shell separately. If interested in qc, store
# volumes and variances.
#============================================================================
uniqueBvals=(`cat ${rawFolder}/shells`)
for b in "${uniqueBvals[@]}"; do
    ${FSLDIR}/bin/select_dwi_vols ${diffFolder}/data ${diffFolder}/bvals ${diffFolder}/mean_b${b} ${b} -m
    if [ ${qcFlag} -eq 1 ]; then
	    ${FSLDIR}/bin/select_dwi_vols ${diffFolder}/data ${diffFolder}/bvals ${prepFolder}/QC/vols_b${b} ${b}
	    ${FSLDIR}/bin/select_dwi_vols ${diffFolder}/data ${diffFolder}/bvals ${prepFolder}/QC/var_b${b} ${b} -v
    fi
    if [ ${b} -eq 0 ]; then
	    ${FSLDIR}/bin/bet ${diffFolder}/mean_b${b} ${diffFolder}/nodif_brain -m -f 0.25 -R
    else
        echo "Fitting DT to b=${b} shell..."
        mkdir -p ${diffFolder}/dtifit_b${b}
        ${FSLDIR}/bin/select_dwi_vols ${diffFolder}/data ${diffFolder}/bvals ${diffFolder}/dtifit_b${b}/b${b} 0 -b ${b} -obv ${diffFolder}/bvecs 
        ${FSLDIR}/bin/dtifit -k ${diffFolder}/dtifit_b${b}/b${b} -o ${diffFolder}/dtifit_b${b}/dti -m ${diffFolder}/nodif_brain_mask -r ${diffFolder}/dtifit_b${b}/b${b}.bvec -b ${diffFolder}/dtifit_b${b}/b${b}.bval --sse --save_tensor
        ${FSLDIR}/bin/fslmaths ${diffFolder}/mean_b${b} -div ${diffFolder}/mean_b0 -mul ${diffFolder}/nodif_brain_mask ${diffFolder}/att_b${b}
    fi
    ${FSLDIR}/bin/fslmaths ${diffFolder}/mean_b${b} -mul ${diffFolder}/nodif_brain_mask ${diffFolder}/mean_b${b}
done


#============================================================================
# Fit Kurtosis model.
#============================================================================
if [ `echo ${#uniqueBvals[@]}` -gt 2 ]; then
    echo "Multi-shell data: fitting DK to all shells..."
    mkdir -p ${diffFolder}/dkifit
    ${FSLDIR}/bin/dtifit -k ${diffFolder}/data -o ${diffFolder}/dkifit/dki -m ${diffFolder}/nodif_brain_mask -r ${diffFolder}/bvecs -b ${diffFolder}/bvals --sse --save_tensor --kurt --kurtdir
fi


echo -e "\n END: runPostProc"

