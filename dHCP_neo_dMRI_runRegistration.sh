#!/bin/bash
set -e
echo -e "\n START: runRegistration"

unset POSIXLY_CORRECT 


if [ "$6" == "" ];then
    echo ""
    echo "usage: $0 <SubjT2wFolder> <SubjFolder> <T2wFolder> <SegmentationFolder> <SurfacesFolder> <DofsFolder>"
    echo "       Registration script"
    echo "       SubjT2wFolder: Path to the output folder for T2w"
    echo "       SubjDiffFolder: Path to the output folder for dMRI"
    echo "       T2wFolder: Path to the folder containing the bias field corrected T2w volumes"
    echo "       SegmentationFolder: Path to the folder containing the segmentations"
    echo "       SurfacesFolder: Path to the folder containing the surfaces"
    echo "       DofsFolder: Path to the folder containing the warps to standard space"
    echo ""
    exit 1
fi

SubjT2wFolder=$1          # Path to subject T2w folder
SubjFolder=$2             # Path to the subject folder
T2wFolder=$3              # T2w folder
SegmentationFolder=$4	  # Segmentation folder
SurfacesFolder=$5         # Surfaces folder
DofsFolder=$6             # Dofs folder for warp fields

SubjDiffFolder=${SubjFolder}/Diffusion

mkdir -p ${SubjT2wFolder}/atlases
mkdir -p ${SubjT2wFolder}/ROIs
mkdir -p ${SubjDiffFolder}/xfms
mkdir -p ${SubjDiffFolder}/Surfaces


#============================================================================
# Copy bias field-corrected T2w volume and atlases in native space
#============================================================================
${FSLDIR}/bin/imcp ${T2wFolder}/T2.nii ${SubjT2wFolder}/T2w.nii
if [ ! -e ${SubjT2wFolder}/T2w.nii.gz ]; then
    gzip -f ${SubjT2wFolder}/T2w.nii
fi
${FSLDIR}/bin/imcp ${SegmentationFolder}/tissue_labels.nii ${SubjT2wFolder}/atlases/tissue_labels_old.nii
if [ ! -e ${SubjT2wFolder}/atlases/tissue_labels_old.nii.gz ]; then
    gzip -f ${SubjT2wFolder}/atlases/tissue_labels_old.nii
fi
${FSLDIR}/bin/fslreorient2std ${SubjT2wFolder}/atlases/tissue_labels_old.nii.gz ${SubjT2wFolder}/atlases/tissue_labels
rm -f ${SubjT2wFolder}/atlases/tissue_labels_old.nii.gz


#============================================================================
# Extract brain and create brain mask
#============================================================================
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels.nii -thr 0.5 -bin ${SubjT2wFolder}/nodif_brain_mask
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/T2w -mul ${SubjT2wFolder}/nodif_brain_mask ${SubjT2wFolder}/brain


#============================================================================
# Register dMRI data to structural T2w using mean_b1000 volume and BBR
#============================================================================
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels.nii -thr 1 -uthr 1 -bin ${SubjT2wFolder}/ROIs/csf_mask
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels.nii -thr 5 -uthr 5 -bin -add ${SubjT2wFolder}/ROIs/csf_mask -bin ${SubjT2wFolder}/ROIs/csf_mask
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels.nii -thr 2 -uthr 2 -bin ${SubjT2wFolder}/ROIs/gm_mask
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels.nii -thr 3 -uthr 3 -bin ${SubjT2wFolder}/ROIs/wm_mask
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/wm_mask -ero -sub ${SubjT2wFolder}/ROIs/wm_mask -abs ${SubjT2wFolder}/ROIs/wm_mask_edges.nii.gz
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/att_b1000.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -out ${SubjDiffFolder}/xfms/diff2str -omat ${SubjDiffFolder}/xfms/diff2str.mat -bins 256 -cost bbr -wmseg ${SubjT2wFolder}/ROIs/wm_mask.nii.gz -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/mean_b0.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -out ${SubjDiffFolder}/xfms/b0_diff2str -omat ${SubjDiffFolder}/xfms/b0_diff2str.mat -bins 256 -cost bbr -wmseg ${SubjT2wFolder}/ROIs/wm_mask.nii.gz -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/att_b1000.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -out ${SubjDiffFolder}/xfms/no_bbr_diff2str -omat ${SubjDiffFolder}/xfms/no_bbr_diff2str.mat -bins 256 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/mean_b0.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -out ${SubjDiffFolder}/xfms/b0_no_bbr_diff2str -omat ${SubjDiffFolder}/xfms/b0_no_bbr_diff2str.mat -bins 256 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp spline
${FSLDIR}/bin/convert_xfm -omat ${SubjDiffFolder}/xfms/str2diff.mat -inverse ${SubjDiffFolder}/xfms/diff2str.mat


#============================================================================
# Create ribbon volume 
#============================================================================
mkdir -p ${SubjT2wFolder}/ROIs/tmp_ribbon
wb_command -create-signed-distance-volume ${SurfacesFolder}/L.pial.native.surf.gii ${SubjT2wFolder}/T2w.nii.gz ${SubjT2wFolder}/ROIs/tmp_ribbon/sign_dist_L.nii
wb_command -create-signed-distance-volume ${SurfacesFolder}/R.pial.native.surf.gii ${SubjT2wFolder}/T2w.nii.gz ${SubjT2wFolder}/ROIs/tmp_ribbon/sign_dist_R.nii
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/sign_dist_L.nii -uthr 0 -abs -bin ${SubjT2wFolder}/ROIs/tmp_ribbon/mask_L
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/sign_dist_R.nii -uthr 0 -abs -bin ${SubjT2wFolder}/ROIs/tmp_ribbon/mask_R
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels -mul ${SubjT2wFolder}/ROIs/tmp_ribbon/mask_L ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_L
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/atlases/tissue_labels -mul ${SubjT2wFolder}/ROIs/tmp_ribbon/mask_R ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_R
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_L -thr 3 -bin -mul 2 ${SubjT2wFolder}/ROIs/tmp_ribbon/in_L
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_L -thr 2 -uthr 2 -bin -mul 3 ${SubjT2wFolder}/ROIs/tmp_ribbon/out_L
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_R -thr 3 -bin -mul 41 ${SubjT2wFolder}/ROIs/tmp_ribbon/in_R
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/tissue_labels_R -thr 2 -uthr 2 -bin -mul 42 ${SubjT2wFolder}/ROIs/tmp_ribbon/out_R
${FSLDIR}/bin/fslmaths ${SubjT2wFolder}/ROIs/tmp_ribbon/in_L -add ${SubjT2wFolder}/ROIs/tmp_ribbon/in_R -add ${SubjT2wFolder}/ROIs/tmp_ribbon/out_L -add ${SubjT2wFolder}/ROIs/tmp_ribbon/out_R ${SubjT2wFolder}/ROIs/ribbon


#============================================================================
# Bring FA and B0 to T2w space and masks to dMRI space
#============================================================================
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/dtifit_b1000/dti_FA.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -applyxfm -init ${SubjDiffFolder}/xfms/diff2str.mat -out ${SubjT2wFolder}/ROIs/dti_FA_T2space.nii.gz -interp spline
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/mean_b0.nii.gz -ref ${SubjT2wFolder}/brain.nii.gz -applyxfm -init ${SubjDiffFolder}/xfms/diff2str.mat -out ${SubjT2wFolder}/B0_T2space.nii.gz -interp spline
${FSLDIR}/bin/flirt -in ${SubjT2wFolder}/ROIs/wm_mask -ref ${SubjDiffFolder}/data -applyxfm -init ${SubjDiffFolder}/xfms/str2diff.mat -out ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz
${FSLDIR}/bin/flirt -in ${SubjT2wFolder}/ROIs/gm_mask -ref ${SubjDiffFolder}/data -applyxfm -init ${SubjDiffFolder}/xfms/str2diff.mat -out ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz
${FSLDIR}/bin/flirt -in ${SubjT2wFolder}/ROIs/ribbon -ref ${SubjDiffFolder}/data -applyxfm -init ${SubjDiffFolder}/xfms/str2diff.mat -out ${SubjFolder}/PreProcessed/QC/ribbon_diff.nii.gz -interp nearestneighbour
${FSLDIR}/bin/fslmaths ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -sub ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz ${SubjFolder}/PreProcessed/QC/tmp
${FSLDIR}/bin/fslmaths ${SubjFolder}/PreProcessed/QC/tmp -thr 0.0001 -mul ${SubjFolder}/PreProcessed/QC/ribbon_diff.nii.gz -bin ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz
${FSLDIR}/bin/fslmaths ${SubjFolder}/PreProcessed/QC/tmp -uthr -0.0001 -mul ${SubjFolder}/PreProcessed/QC/ribbon_diff.nii.gz -abs -bin ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz
${FSLDIR}/bin/imrm ${SubjFolder}/PreProcessed/QC/tmp


#============================================================================
# Obtain warp fields from template to structural T2w space and compute warps from dw space to template
#============================================================================
age=`cat ${SubjFolder}/age`
${FSLDIR}/bin/imcp ${DofsFolder}/template-${age}-n.nii ${SubjDiffFolder}/xfms/std2str_warp
${FSLDIR}/bin/invwarp -w ${SubjDiffFolder}/xfms/std2str_warp -o ${SubjDiffFolder}/xfms/str2std_warp -r /vols/Data/baby/NEOSEG/data/trimmed-atlas2/template-${age}
${FSLDIR}/bin/convertwarp --ref=/vols/Data/baby/NEOSEG/data/trimmed-atlas2/template-${age} --premat=${SubjDiffFolder}/xfms/diff2str.mat --warp1=${SubjDiffFolder}/xfms/str2std_warp --out=${SubjDiffFolder}/xfms/diff2std_warp
${FSLDIR}/bin/invwarp -w ${SubjDiffFolder}/xfms/diff2std_warp -o ${SubjDiffFolder}/xfms/std2diff_warp -r ${SubjDiffFolder}/mean_b0.nii.gz

${FSLDIR}/bin/imcp /vols/Data/baby/NEOSEG/data/trimmed-atlas2/template-${age} ${SubjT2wFolder}/template
if [ "$age" -ne "44" ]
then
    ${FSLDIR}/bin/imcp ${templateFolder}/atlas_warps/template-${age}_to_template-44.warp.nii.gz ${SubjDiffFolder}/xfms/age244w_warp
    ${FSLDIR}/bin/imcp ${templateFolder}/atlas_warps/template-44_to_template-${age}.warp.nii.gz ${SubjDiffFolder}/xfms/44w2age_warp
fi


#============================================================================
# Map microstructural indices on surfaces
#============================================================================
${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/dtifit_b1000/dti_FA -ref ${SubjT2wFolder}/brain -applyxfm -init ${SubjDiffFolder}/xfms/diff2str.mat -out ${SubjDiffFolder}/Surfaces/tmp.nii.gz
wb_command -volume-to-surface-mapping ${SubjDiffFolder}/Surfaces/tmp.nii.gz ${SurfacesFolder}/R.white.native.surf.gii ${SubjDiffFolder}/Surfaces/b1p0k.FA.R.white.native.shape.gii -cubic
wb_command -volume-to-surface-mapping ${SubjDiffFolder}/Surfaces/tmp.nii.gz ${SurfacesFolder}/L.white.native.surf.gii ${SubjDiffFolder}/Surfaces/b1p0k.FA.L.white.native.shape.gii -cubic

${FSLDIR}/bin/flirt -in ${SubjDiffFolder}/dtifit_b1000/dti_MD -ref ${SubjT2wFolder}/brain -applyxfm -init ${SubjDiffFolder}/xfms/diff2str.mat -out ${SubjDiffFolder}/Surfaces/tmp.nii.gz
wb_command -volume-to-surface-mapping ${SubjDiffFolder}/Surfaces/tmp.nii.gz ${SurfacesFolder}/R.white.native.surf.gii ${SubjDiffFolder}/Surfaces/b1p0k.MD.R.white.native.shape.gii -cubic
wb_command -volume-to-surface-mapping ${SubjDiffFolder}/Surfaces/tmp.nii.gz ${SurfacesFolder}/L.white.native.surf.gii ${SubjDiffFolder}/Surfaces/b1p0k.MD.L.white.native.shape.gii -cubic

${FSLDIR}/bin/imrm ${SubjDiffFolder}/Surfaces/tmp.nii.gz

#============================================================================
# Quality Control
#============================================================================
${FSLDIR}/bin/fslmaths ${SubjFolder}/PreProcessed/QC/var_b0.nii.gz -sqrt ${SubjFolder}/PreProcessed/QC/std_b0.nii.gz
${FSLDIR}/bin/fslmaths ${SubjDiffFolder}/mean_b0 -div ${SubjFolder}/PreProcessed/QC/std_b0 -mul ${SubjDiffFolder}/nodif_brain_mask ${SubjFolder}/PreProcessed/QC/tSNR_b0
score=`$FSLDIR/bin/fslcc -m ${SubjT2wFolder}/nodif_brain_mask ${SubjT2wFolder}/brain ${SubjT2wFolder}/B0_T2space.nii.gz  | awk '{print $3}'`
tSNR_wm_m=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/tSNR_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -M  | awk '{print $1}'`
tSNR_wm_s=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/tSNR_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -S  | awk '{print $1}'`
tSNR_gm_m=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/tSNR_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -M  | awk '{print $1}'`
tSNR_gm_s=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/tSNR_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -S  | awk '{print $1}'`
B0_wm_m=`$FSLDIR/bin/fslstats ${SubjDiffFolder}/mean_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -M  | awk '{print $1}'`
B0_wm_s=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/std_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -M  | awk '{print $1}'`
B0_gm_m=`$FSLDIR/bin/fslstats ${SubjDiffFolder}/mean_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -M  | awk '{print $1}'`
B0_gm_s=`$FSLDIR/bin/fslstats ${SubjFolder}/PreProcessed/QC/std_b0.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -M  | awk '{print $1}'`
CNR_wm=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -M`)
CNR_gm=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -M`)
CNR_wm_s=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -S`)
CNR_gm_s=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_cnr_maps.nii.gz -k ${SubjFolder}/PreProcessed/QC/gm_mask_diff.nii.gz -S`)
$FSLDIR/bin/fslmaths ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_residuals.nii.gz -mul ${SubjFolder}/PreProcessed/eddy/eddy_corrected.eddy_residuals.nii.gz ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared
$FSLDIR/bin/select_dwi_vols ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared ${SubjDiffFolder}/bvals ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b0 0
$FSLDIR/bin/select_dwi_vols ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared ${SubjDiffFolder}/bvals ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b400 400
$FSLDIR/bin/select_dwi_vols ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared ${SubjDiffFolder}/bvals ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b1000 1000
$FSLDIR/bin/select_dwi_vols ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared ${SubjDiffFolder}/bvals ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b2600 2600
Res_wm_b0=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b0 -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -m`)
Res_wm_b400=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b400 -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -m`)
Res_wm_b1000=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b1000 -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -m`)
Res_wm_b2600=(`$FSLDIR/bin/fslstats -t ${SubjFolder}/PreProcessed/QC/eddy_residuals_squared_b2600 -k ${SubjFolder}/PreProcessed/QC/wm_mask_diff.nii.gz -m`)

# Write .json file
echo "{" > ${SubjT2wFolder}/B0_T2space.json
echo "   \"Coreg_score\": $score," >> ${SubjT2wFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b0[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B0\": [$tmp]," >> ${SubjT2wFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b400[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B400\": [$tmp]," >> ${SubjT2wFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b1000[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B1000\": [$tmp]," >> ${SubjT2wFolder}/B0_T2space.json
tmp=$(printf ", %s" "${Res_wm_b2600[@]}")
tmp=${tmp:2}
echo "   \"Avg_Res_B2600\": [$tmp]," >> ${SubjT2wFolder}/B0_T2space.json

echo "   \"tSNR_avg_wm\": ${CNR_wm[0]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"tSNR_std_wm\": ${CNR_wm_s[0]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"tSNR_avg_gm\": ${CNR_gm[0]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"tSNR_std_gm\": ${CNR_gm_s[0]}," >> ${SubjT2wFolder}/B0_T2space.json

echo "   \"CNR_b400_avg_wm\": ${CNR_wm[1]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"CNR_b400_std_wm\": ${CNR_wm_s[1]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"CNR_b1000_avg_wm\": ${CNR_wm[2]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"CNR_b1000_std_wm\": ${CNR_wm_s[2]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"CNR_b2600_avg_wm\": ${CNR_wm[3]}," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"CNR_b2600_std_wm\": ${CNR_wm_s[3]}," >> ${SubjT2wFolder}/B0_T2space.json

echo "   \"B0_avg_wm\": $B0_wm_m," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"B0_avgStd_wm\": $B0_wm_s," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"B0_avg_gm\": $B0_gm_m," >> ${SubjT2wFolder}/B0_T2space.json
echo "   \"B0_avgStd_gm\": $B0_gm_s" >> ${SubjT2wFolder}/B0_T2space.json
echo "}" >> ${SubjT2wFolder}/B0_T2space.json

echo "PASS" > ${SubjT2wFolder}/regPassCheck

echo -e "\n END: runRegistration_v5"
