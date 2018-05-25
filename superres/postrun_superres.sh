#!/bin/bash
set -e
echo -e "\n START: postrun_superres"


if [ "$1" == "" ];then
    echo ""
    echo "usage: $0 <4Dfile> "
    echo "       Post SuperResolution script"
    echo ""
    echo "       4Dfile: raw 4D data file"
    echo ""
    exit 1
fi

dataFile=$1

pathToFile=`dirname ${dataFile}` 

# Merge the results and clean temporary files/folders
${FSLDIR}/bin/fslmerge -t ${pathToFile}/data_sr `cat ${pathToFile}/tmp/fileList`

rm -rf ${pathToFile}/tmp


echo -e "\n END: postrun_superres"
