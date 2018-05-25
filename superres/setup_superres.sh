#!/bin/bash
set -e
echo -e "\n START: setup_superres"


if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <4Dfile> <MaskFile> <OutCommandFile> <NoVols>"
    echo "       SuperResolution preparation script"
    echo ""
    echo "       4Dfile: raw 4D data file"
    echo "       MaskFile: raw data binary mask file"
    echo "       OutCommandFile: text file containing fsl_sub list of parallel commands"
    echo "       NoVols: number of raw data volumes"
    echo ""
    exit 1
fi

dataFile=$1  
maskFile=$2
outFile=$3
n=$4

# Number of parallel jobs in series
nseries=30

pathToFile=`dirname ${dataFile}` 


cnt=0
cmd=""
rm -rf ${outFile}
for ((ii=0;ii<n;ii++));do
   
    if [ ${cnt} -eq ${nseries} ]; then
	echo ${cmd} >> ${outFile}
	cmd=""
	cnt=0
    fi

    if [ ${cnt} -lt ${nseries} ];then
	cmd="cd ${pathToFile}/tmp/tmp_${ii};${IRTKPATH}/reconstructiononly ${pathToFile}/tmp/tmp_${ii}/recon_${ii}.nii.gz 1 ${pathToFile}/tmp/tmp_${ii}/tmp_${ii}.nii.gz -mask ${maskFile} -no_robust_statistics -iterations 1 -delta 100000 -lastIter 0.004 -1D -thickness 2.6 -no_intensity_matching;cd ${pathToFile};$cmd"
    fi
    let "cnt+=1"
    
done

echo ${cmd} >> ${outFile}


echo -e "\n END: runSuperResolution_parallel"



