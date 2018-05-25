#!/bin/bash
set -e
echo -e "\n START: prerun_superres"


if [ "$1" == "" ];then
    echo ""
    echo "usage: $0 <4Dfile> "
    echo "       SuperResolution preparation script"
    echo ""
    echo "       4Dfile: raw 4D data file"
    echo ""
    exit 1
fi

dataFile=$1

pathToFile=`dirname ${dataFile}` 

rm -rf ${pathToFile}/tmp
mkdir -p ${pathToFile}/tmp


# Split 4D data file for superresolution script
${FSLDIR}/bin/fslsplit ${dataFile} ${pathToFile}/tmp/vol_  
# Loop through each 3D volume and move it to its separate folder; store the list of individual 3D volumes to super-resolve
ii=0
for f in `imglob ${pathToFile}/tmp/vol_*`; do
    mkdir -p ${pathToFile}/tmp/tmp_${ii}
    mv ${f}.nii.gz ${pathToFile}/tmp/tmp_${ii}/tmp_${ii}.nii.gz
    echo -n "${pathToFile}/tmp/tmp_${ii}/recon_${ii}.nii.gz " >> ${pathToFile}/tmp/fileList
    let "ii+=1"
done


echo -e "\n END: prerun_superres"

