#!/bin/bash

set -e
echo -e "\n Getting the best b0s..."

#============================================================================
# Identify best b0 pairs for every PE direction
#============================================================================
unset POSIXLY_CORRECT   # to perform floats comparison

scriptsFolder=/home/fs0/matteob/scripts/dHCP
PE=("LR" "RL" "AP" "PA")

TopupFolder=$1          # "$1" #Path to /PreProcessed/topup folder
PEdir="${PE[$2]}"       # "$2" #Phase encoding direction ID (e.g. 0 for LR)
noB0s=$3                # "$3" #Number of B0 volumes used to estimate susceptibility distortions

IN=`$FSLDIR/bin/imglob ${TopupFolder}/${PEdir}_B0s.nii.gz`
OUT=`$FSLDIR/bin/remove_ext ${TopupFolder}/${PEdir}_B0s.nii.gz`

rm -rf ${OUT}_tmp
mkdir ${OUT}_tmp
$FSLDIR/bin/fslsplit $IN ${OUT}_tmp/grot

#============================================================================
# Compute coefficient of variations (CoVs=std(Z)/avg(Z)) of the slice profile
# for each b0 volume using a set of slices
#============================================================================
${FSLDIR}/bin/fslroi ${TopupFolder}/"${PEdir}"_B0s.nii.gz ${TopupFolder}/tmp_ROI 0 -1 0 -1 19 25 0 -1
${FSLDIR}/bin/fslmaths ${TopupFolder}/tmp_ROI -Xmean -Ymean -Zstd  ${TopupFolder}/tmp_slProfStd
${FSLDIR}/bin/fslmaths ${TopupFolder}/tmp_ROI -Xmean -Ymean -Zmean  ${TopupFolder}/tmp_slProfAvg
${FSLDIR}/bin/fslmaths ${TopupFolder}/tmp_slProfStd -div ${TopupFolder}/tmp_slProfAvg ${TopupFolder}/tmp_slProfCov 
covs=(`${FSLDIR}/bin/fslstats -t ${TopupFolder}/tmp_slProfCov -m`)
echo ${covs[@]}
for f in `$FSLDIR/bin/imglob ${OUT}_tmp/grot*` ; do
    ff=`echo ${f} | sed 's/grot//g'`
    ff=`basename ${ff}`
    echo ${ff} `echo "${covs[10#${ff}]}"` >> ${OUT}_tmp/covs.txt
done


#============================================================================
# If only 1 b0 volume, do nothing
# If 2 b0s, look for the best between the two using the CoV
# If more than 2 b0s, compute correlations between each pair and store results
#============================================================================
count=0
N=`$FSLDIR/bin/imglob ${OUT}_tmp/grot*`
N=`echo $N | wc -w`
if [ $N = 1 ] ; then
    best=0
elif [ $N = 2 ] ; then
    best=(`cat ${OUT}_tmp/covs.txt | sort -k 2 -n | head -n 1 | awk '{print $1}'`)
    echo ${best}
    $FSLDIR/bin/imcp ${OUT}_tmp/grot${best}.nii.gz ${TopupFolder}/${PEdir}_B0s.nii.gz
elif [ $N -gt 2 ] ; then
    for f in `${FSLDIR}/bin/imglob ${OUT}_tmp/grot*` ; do
	ff=`echo ${f} | sed 's/grot//g'`
	ff=`basename ${ff}`
	scores[10#${ff}]=0
    done

    for f in `${FSLDIR}/bin/imglob ${OUT}_tmp/grot*` ; do
	ff=`echo ${f} | sed 's/grot//g'`
	ff=`basename ${ff}`
	for g in `$FSLDIR/bin/imglob ${OUT}_tmp/grot*` ; do
	    gg=`echo ${g} | sed 's/grot//g'`
	    gg=`basename ${gg}`
	    if [ ${gg} -gt ${ff} ] ; then
		$FSLDIR/bin/flirt -in ${f} -ref ${g} -nosearch -dof 6 -o ${OUT}_tmp/blah -omat ${OUT}_tmp/blah.mat
		score=`${FSLDIR}/bin/fslcc -t -1 -p 10 ${g} ${OUT}_tmp/blah | awk '{print $3}'`
		scores[10#${ff}]=`echo 10 k ${scores[10#${ff}]} ${score} + p | dc -`
		scores[10#${gg}]=`echo 10 k ${scores[10#${gg}]} ${score} + p | dc -`
		#echo $f $g $score ${scores[$ff]} ${scores[$gg]}
	    fi
	done
	count=`echo ${count}  + 1  |bc`
    done

    for f in `${FSLDIR}/bin/imglob ${OUT}_tmp/grot*` ; do
	ff=`echo ${f} | sed 's/grot//g'`
	ff=`basename ${ff}`
	echo ${ff} `echo "${scores[10#${ff}]}  / (${count} -1)" | bc -l` >> ${OUT}_tmp/scores.txt
    done

    best=(`cat ${OUT}_tmp/scores.txt | sort -k 2 -n -r | head -n ${noB0s} | awk '{print $1}'`)

    echo ${best[@]}
    for i in $(seq 0 $((${noB0s}-1))) ; do
	bestVols[$i]=${OUT}_tmp/grot${best[$i]}
    done
    echo ${bestVols[@]}
    ${FSLDIR}/bin/fslmerge -t ${TopupFolder}/${PEdir}_B0s.nii.gz ${bestVols[@]}.nii.gz
fi


#============================================================================
# For current PE direction, write the score (either CoV or 1-rho) and 
# corresponding volume number to disk
#============================================================================
idxL=0
while read line
do
    if [ ${idxL} -eq ${2} ] ; then
	tmp=(${line})
	if [ ${N} -eq 1 ]; then
	    echo "${2}" "${tmp[0]} 1"  >> ${TopupFolder}/idxBestB0s.txt
	elif [ ${N} -eq 2 ]; then
	    echo "${2}" "${tmp[$((10#${best[0]}))]}" `echo "${covs[$((10#${best[0]}))]}"` >> ${TopupFolder}/idxBestB0s.txt
	elif [ ${N} -gt 2 ]; then
	    echo "${2}" "${tmp[$((10#${best[0]}))]}" `echo "1 - (${scores[$((10#${best[0]}))]} / (${count} -1))" | bc -l` >> ${TopupFolder}/idxBestB0s.txt
	fi
    fi
    idxL=$((${idxL} + 1))
done < ${TopupFolder}/b0Indices


#============================================================================
# Clean temporary files
#============================================================================
#rm -rf ${OUT}_tmp
#rm -f ${TopupFolder}/tmp_*


echo -e "\n END: found best b0s."


