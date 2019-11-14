#!/bin/bash
set -e
echo -e "\n START: generatePNGs"


sFolder=$1

app_list=" "
hor_gap=5
ver_gap=1

$FSLDIR/bin/overlay 0 0 ${sFolder}/Diffusion/xfms/diff2str.nii.gz 0 0.7 ${sFolder}/T2w/segmentation/wm_mask_edges.nii.gz 0.1 1 ${sFolder}/PreProcessed/QC/regOverlay
$FSLDIR/bin/slicer ${sFolder}/PreProcessed/QC/regOverlay -L -S 9 1160 ${sFolder}/PreProcessed/QC/regOverlay.png

$FSLDIR/bin/slicer ${sFolder}/Diffusion/mean_b0.nii.gz -i 0 60 -a ${sFolder}/PreProcessed/QC/b0.png
$FSLDIR/bin/slicer ${sFolder}/Diffusion/mean_b400.nii.gz -i 0 40 -a ${sFolder}/PreProcessed/QC/b400.png
$FSLDIR/bin/slicer ${sFolder}/Diffusion/mean_b1000.nii.gz -i 0 30 -a ${sFolder}/PreProcessed/QC/b1000.png
$FSLDIR/bin/slicer ${sFolder}/Diffusion/mean_b2600.nii.gz -i 0 10 -a ${sFolder}/PreProcessed/QC/b2600.png



echo -e "\n END: generatePNGs"
