#!/bin/bash


set -e
echo -e "\n START: getMasks"

unset POSIXLY_CORRECT 


if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <SubjFolder> <TissueLabels>"
    echo "       Tissue and brain masks extraction script"
    echo "       SubjFolder: Path to the subject processing folder"
    echo "       TissueLabels: Volume containing results of tissue segmentations (assumes 1=CSF, 2=GM, 3=WM, 5=CSF)"
    echo ""
    exit 1
fi


subjOutFolder=$1          # Path to the subject folder
segVolume=$2              # Segmented volume (assumes 1=CSF, 2=GM, 3=WM, 5=CSF)

anatFolder=${subjOutFolder}/T2w

mkdir -p ${anatFolder}/segmentation


#============================================================================
# Get single tissue masks in T2w space
#============================================================================
${FSLDIR}/bin/imcp ${segVolume} ${anatFolder}/segmentation/tissue_labels.nii   # Copy segmented volume to processing folder

${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/tissue_labels.nii -thr 1 -uthr 1 -bin ${anatFolder}/segmentation/csf_mask   # CSF
${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/tissue_labels.nii -thr 5 -uthr 5 -bin -add ${anatFolder}/segmentation/csf_mask -bin ${anatFolder}/segmentation/csf_mask   # Adding ventricles
${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/tissue_labels.nii -thr 2 -uthr 2 -bin ${anatFolder}/segmentation/gm_mask   # GM
${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/tissue_labels.nii -thr 3 -uthr 3 -bin ${anatFolder}/segmentation/wm_mask   # WM
${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/wm_mask -ero -sub ${anatFolder}/segmentation/wm_mask -abs ${anatFolder}/segmentation/wm_mask_edges.nii.gz   # WM edges

#============================================================================
# Create brain mask
#============================================================================
${FSLDIR}/bin/fslmaths ${anatFolder}/segmentation/tissue_labels.nii -thr 0 -bin ${anatFolder}/segmentation/brain_mask


echo -e "\n END: getMasks"
