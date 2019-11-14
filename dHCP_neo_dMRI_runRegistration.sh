#!/bin/bash


set -e
echo -e "\n START: runRegistration"

unset POSIXLY_CORRECT 


if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <SubjFolder> <SubjT2> <bbr_flag> <reg2std_flag>"
    echo "       Registration script"
    echo "       SubjFolder: Path to the subject processing folder"
    echo "       SubjT2: Subject T2-weighted volume"
    echo "       bbr_flag: 0=do not use BBR, 1=use BBR (linear)"
    echo "       reg2std_flag: 0=do not register to template, 1=register to template (non-linear)"
    echo ""
    exit 1
fi


subjOutFolder=$1          # Path to the subject folder
subjT2=$2                 # Subject T2-weighted volume
wmseg=$3                  # White matter segmentation volume (0=do not use BBR)
reg2std=$4                # 0=do not register to template, 1=register to template (non-linear)

prepFolder=${subjOutFolder}/PreProcessed
anatFolder=${subjOutFolder}/T2w
diffFolder=${subjOutFolder}/Diffusion

mkdir -p ${anatFolder}/ants
mkdir -p ${diffFolder}/xfms
mkdir -p ${diffFolder}/masks


#============================================================================
# Copy T2w volume in processing folder
#============================================================================
${FSLDIR}/bin/imcp ${subjT2} ${anatFolder}/T2w.nii


#============================================================================
# Extract brain using brain mask from segmented volume
#============================================================================
${FSLDIR}/bin/fslmaths ${anatFolder}/T2w -mul ${anatFolder}/segmentation/brain_mask ${anatFolder}/T2w_brain


#============================================================================
# Register dMRI data to structural T2w using mean_b1000 volume and BBR 
# (if requested)
#============================================================================
if [ -e ${wmseg} ]; then 
    echo "White matter segmentation detected. Using BBR"
    ${FSLDIR}/bin/flirt -in ${diffFolder}/att_b1000.nii.gz -ref ${anatFolder}/T2w_brain.nii.gz -out ${diffFolder}/xfms/diff2str -omat ${diffFolder}/xfms/diff2str.mat \
                    -bins 256 -cost bbr -wmseg ${anatFolder}/segmentation/wm_mask.nii.gz -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
else
    echo "White matter segmentation not found. No BBR"
    ${FSLDIR}/bin/flirt -in ${diffFolder}/att_b1000.nii.gz -ref ${anatFolder}/T2w_brain.nii.gz -out ${diffFolder}/xfms/diff2str -omat ${diffFolder}/xfms/diff2str.mat \
                    -bins 256 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
fi
${FSLDIR}/bin/convert_xfm -omat ${diffFolder}/xfms/str2diff.mat -inverse ${diffFolder}/xfms/diff2str.mat


#============================================================================
# Bring FA and b0 to T2w space and tissue/brain masks to dMRI space
#============================================================================
${FSLDIR}/bin/flirt -in ${diffFolder}/dtifit_b1000/dti_FA.nii.gz -ref ${anatFolder}/T2w_brain.nii.gz -applyxfm -init ${diffFolder}/xfms/diff2str.mat -out ${anatFolder}/dti_FA_T2space.nii.gz -interp spline
${FSLDIR}/bin/flirt -in ${diffFolder}/mean_b0.nii.gz -ref ${anatFolder}/T2w_brain.nii.gz -applyxfm -init ${diffFolder}/xfms/diff2str.mat -out ${anatFolder}/B0_T2space.nii.gz -interp spline

if [ -e ${wmseg} ]; then 
    ${FSLDIR}/bin/flirt -in ${anatFolder}/segmentation/wm_mask -ref ${diffFolder}/mean_b0.nii.gz -applyxfm -init ${diffFolder}/xfms/str2diff.mat -out ${diffFolder}/masks/wm_mask.nii.gz -interp nearestneighbour
fi
if [ -e ${anatFolder}/segmentation/gm_mask.nii.gz ]; then 
    ${FSLDIR}/bin/flirt -in ${anatFolder}/segmentation/gm_mask -ref ${diffFolder}/mean_b0.nii.gz -applyxfm -init ${diffFolder}/xfms/str2diff.mat -out ${diffFolder}/masks/gm_mask.nii.gz -interp nearestneighbour
fi
if [ -e ${anatFolder}/segmentation/csf_mask.nii.gz ]; then 
    ${FSLDIR}/bin/flirt -in ${anatFolder}/segmentation/csf_mask -ref ${diffFolder}/mean_b0.nii.gz -applyxfm -init ${diffFolder}/xfms/str2diff.mat -out ${diffFolder}/masks/csf_mask.nii.gz -interp nearestneighbour
fi
${FSLDIR}/bin/flirt -in ${anatFolder}/segmentation/brain_mask -ref ${diffFolder}/mean_b0.nii.gz -applyxfm -init ${diffFolder}/xfms/str2diff.mat -out ${diffFolder}/masks/brain_mask.nii.gz -interp nearestneighbour


#============================================================================
# Estimate warp fields from structural T2w to age-matched template space and 
# compute warps from dw space to template (if required)
#============================================================================
if [ "${reg2std}" -eq "1" ]; then 

    age=`cat ${subjOutFolder}/age`

    # Get age-matched atlas volume
    ${FSLDIR}/bin/imcp ${templateFolder}/T2/template-${age} ${anatFolder}/template

    ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -f ${anatFolder}/template.nii.gz -m ${anatFolder}/T2w_brain.nii.gz -o ${anatFolder}/ants/ants_sub2std_ -t 'b' -r 8 -j 1

    ${C3DPATH}/c3d_affine_tool -ref ${anatFolder}/template.nii.gz -src ${anatFolder}/T2w_brain.nii.gz -itk ${anatFolder}/ants/ants_sub2std_0GenericAffine.mat \
                             -ras2fsl -o ${anatFolder}/ants/ants_sub2std_affine_flirt.mat
    ${C3DPATH}/c3d -mcs ${anatFolder}/ants/ants_sub2std_1Warp.nii.gz -oo ${anatFolder}/ants/wx.nii.gz ${anatFolder}/ants/wy.nii.gz ${anatFolder}/ants/wz.nii.gz
    ${FSLDIR}/bin/fslmaths ${anatFolder}/ants/wy -mul -1 ${anatFolder}/ants/i_wy
    ${FSLDIR}/bin/fslmerge -t ${anatFolder}/ants/ants_sub2std_warp_fnirt ${anatFolder}/ants/wx ${anatFolder}/ants/i_wy ${anatFolder}/ants/wz
    ${FSLDIR}/bin/convertwarp --ref=${anatFolder}/template --premat=${anatFolder}/ants/ants_sub2std_affine_flirt.mat \
                          --warp1=${anatFolder}/ants/ants_sub2std_warp_fnirt --out=${diffFolder}/xfms/str2std_warp
    ${FSLDIR}/bin/invwarp -w ${diffFolder}/xfms/str2std_warp -o ${diffFolder}/xfms/std2str_warp -r ${anatFolder}/T2w_brain.nii.gz

    ${FSLDIR}/bin/convertwarp --ref=${anatFolder}/template --premat=${diffFolder}/xfms/diff2str.mat \
                          --warp1=${diffFolder}/xfms/str2std_warp --out=${diffFolder}/xfms/diff2std_warp
    ${FSLDIR}/bin/invwarp -w ${diffFolder}/xfms/diff2std_warp -o ${diffFolder}/xfms/std2diff_warp -r ${diffFolder}/mean_b0.nii.gz

    # If necessary, get warp from age-matched template to 40th week
    if [ "$age" -ne "40" ]; then
        ${FSLDIR}/bin/convertwarp --ref=${templateFolder}/T2/template-40 --warp1=${diffFolder}/xfms/diff2std_warp \
                              --warp2=${templateFolder}/allwarps/template-${age}_to_template-40_warp.nii.gz --out=${diffFolder}/xfms/diff2std40w_warp
        ${FSLDIR}/bin/convertwarp --ref=${diffFolder}/mean_b0.nii.gz --warp1=${templateFolder}/allwarps/template-40_to_template-${age}_warp.nii.gz \
                              --warp2=${diffFolder}/xfms/std2diff_warp --out=${diffFolder}/xfms/std40w2diff_warp
    else
        ${FSLDIR}/bin/imcp ${diffFolder}/xfms/diff2std_warp ${diffFolder}/xfms/diff2std40w_warp
        ${FSLDIR}/bin/imcp ${diffFolder}/xfms/std2diff_warp ${diffFolder}/xfms/std40w2diff_warp
    fi

fi


#============================================================================
# Quality Control
#============================================================================
# Registration score
score=`${FSLDIR}/bin/fslcc -m ${anatFolder}/segmentation/brain_mask ${anatFolder}/T2w_brain ${anatFolder}/B0_T2space.nii.gz  | awk '{print $3}'`

# Mean and std tissue-specific b0 intensity
${FSLDIR}/bin/fslmaths ${prepFolder}/QC/var_b0.nii.gz -sqrt ${prepFolder}/QC/std_b0.nii.gz
B0_wm_m=`${FSLDIR}/bin/fslstats ${diffFolder}/mean_b0.nii.gz -k ${diffFolder}/masks/wm_mask.nii.gz -M  | awk '{print $1}'`
B0_gm_m=`${FSLDIR}/bin/fslstats ${diffFolder}/mean_b0.nii.gz -k ${diffFolder}/masks/gm_mask.nii.gz -M  | awk '{print $1}'`
B0_wm_s=`${FSLDIR}/bin/fslstats ${prepFolder}/QC/std_b0.nii.gz -k ${diffFolder}/masks/wm_mask.nii.gz -M  | awk '{print $1}'`
B0_gm_s=`${FSLDIR}/bin/fslstats ${prepFolder}/QC/std_b0.nii.gz -k ${diffFolder}/masks/gm_mask.nii.gz -M  | awk '{print $1}'`

# Tissue-specific CNR mean and std
CNR_wm=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${diffFolder}/masks/wm_mask.nii.gz -M`)
CNR_gm=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${diffFolder}/masks/gm_mask.nii.gz -M`)
CNR_wm_s=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${diffFolder}/masks/wm_mask.nii.gz -S`)
CNR_gm_s=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${diffFolder}/masks/gm_mask.nii.gz -S`)

# White matter-specific average shell-wise squared residual
${FSLDIR}/bin/fslmaths ${prepFolder}/eddy/eddy_corrected.eddy_residuals.nii.gz -mul ${prepFolder}/eddy/eddy_corrected.eddy_residuals.nii.gz ${prepFolder}/QC/eddy_residuals_squared
${FSLDIR}/bin/select_dwi_vols ${prepFolder}/QC/eddy_residuals_squared ${diffFolder}/bvals ${prepFolder}/QC/eddy_residuals_squared_b0 0
${FSLDIR}/bin/select_dwi_vols ${prepFolder}/QC/eddy_residuals_squared ${diffFolder}/bvals ${prepFolder}/QC/eddy_residuals_squared_b400 400
${FSLDIR}/bin/select_dwi_vols ${prepFolder}/QC/eddy_residuals_squared ${diffFolder}/bvals ${prepFolder}/QC/eddy_residuals_squared_b1000 1000
${FSLDIR}/bin/select_dwi_vols ${prepFolder}/QC/eddy_residuals_squared ${diffFolder}/bvals ${prepFolder}/QC/eddy_residuals_squared_b2600 2600
Res_wm_b0=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/QC/eddy_residuals_squared_b0 -k ${diffFolder}/masks/wm_mask.nii.gz -m`)
Res_wm_b400=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/QC/eddy_residuals_squared_b400 -k ${diffFolder}/masks/wm_mask.nii.gz -m`)
Res_wm_b1000=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/QC/eddy_residuals_squared_b1000 -k ${diffFolder}/masks/wm_mask.nii.gz -m`)
Res_wm_b2600=(`${FSLDIR}/bin/fslstats -t ${prepFolder}/QC/eddy_residuals_squared_b2600 -k ${diffFolder}/masks/wm_mask.nii.gz -m`)

# Write .json file
echo "{" > ${anatFolder}/B0_T2space.json
echo "   \"Coreg_score\": $score," >> ${anatFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b0[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B0\": [$tmp]," >> ${anatFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b400[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B400\": [$tmp]," >> ${anatFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b1000[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B1000\": [$tmp]," >> ${anatFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b2600[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B2600\": [$tmp]," >> ${anatFolder}/B0_T2space.json

echo "   \"tSNR_avg_wm\": ${CNR_wm[0]}," >> ${anatFolder}/B0_T2space.json
echo "   \"tSNR_std_wm\": ${CNR_wm_s[0]}," >> ${anatFolder}/B0_T2space.json
echo "   \"tSNR_avg_gm\": ${CNR_gm[0]}," >> ${anatFolder}/B0_T2space.json
echo "   \"tSNR_std_gm\": ${CNR_gm_s[0]}," >> ${anatFolder}/B0_T2space.json

echo "   \"CNR_b400_avg_wm\": ${CNR_wm[1]}," >> ${anatFolder}/B0_T2space.json
echo "   \"CNR_b400_std_wm\": ${CNR_wm_s[1]}," >> ${anatFolder}/B0_T2space.json
echo "   \"CNR_b1000_avg_wm\": ${CNR_wm[2]}," >> ${anatFolder}/B0_T2space.json
echo "   \"CNR_b1000_std_wm\": ${CNR_wm_s[2]}," >> ${anatFolder}/B0_T2space.json
echo "   \"CNR_b2600_avg_wm\": ${CNR_wm[3]}," >> ${anatFolder}/B0_T2space.json
echo "   \"CNR_b2600_std_wm\": ${CNR_wm_s[3]}," >> ${anatFolder}/B0_T2space.json

echo "   \"B0_avg_wm\": $B0_wm_m," >> ${anatFolder}/B0_T2space.json
echo "   \"B0_avgStd_wm\": $B0_wm_s," >> ${anatFolder}/B0_T2space.json
echo "   \"B0_avg_gm\": $B0_gm_m," >> ${anatFolder}/B0_T2space.json
echo "   \"B0_avgStd_gm\": $B0_gm_s" >> ${anatFolder}/B0_T2space.json
echo "}" >> ${anatFolder}/B0_T2space.json

echo "PASS" > ${anatFolder}/regPassCheck

echo -e "\n END: runRegistration"
