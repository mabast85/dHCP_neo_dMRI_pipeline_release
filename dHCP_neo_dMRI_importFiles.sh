#!/bin/bash


set -e
echo -e "\n START: Importing files"

# scriptsFolder=/home/fs0/matteob/scripts/dHCP

if [ "$6" == "" ];then
    echo ""
    echo "usage: $0 <Data folder> <Data filename> <Output preprocessing folder> <Acquisition protocol> <Number of volumes> <Number of b0s>"
    echo "       Data folder: Path to the data file"
    echo "       Data filename: File name for the raw data"
    echo "       Output preprocessing folder: Path to the output pre-processing folder"
    echo "       Acqusition protocol: Text file with acquisition parameters"
    echo "       Number of volumes: Number of acquired volumes"
    echo "       Number of b0s: Number of b0s from each phase encoding block to use when estimating the fieldmap"
    echo ""
    exit 1
fi


dataFolder=$1      # Path to data file
dataFile=$2        # Data file name
prepFolder=$3   # Output folder
acqProt=$4         # Acquisition protcol
nVols=$5           # Number of acquired volumes
noB0s=$6           # Number of B0 volumes for each PE direction used to estimate distortions with TOPUP


#============================================================================
# Separate b0 volumes according to their PE direction and obtain 
# bvals and bvecs files. Round bvals to identify shells.
#============================================================================
idxLR=0
idxRL=0
idxAP=0
idxPA=0
LRvols=-1
RLvols=-1
APvols=-1
PAvols=-1
no_LR=0
no_RL=0
no_AP=0
no_PA=0
idxb400=0
idxb1000=0
idxb2600=0
i=0

echo -n > ${prepFolder}/eddy/eddyIndex.txt
while read line; do
    bvec_x[i]=`echo $line | awk {'print $1'}`
    bvec_y[i]=`echo $line | awk {'print $2'}`
    bvec_z[i]=`echo $line | awk {'print $3'}`
    bval[i]=`echo $line | awk {'print $4'}`
    pedir[i]=`echo $line | awk {'print $5'}`
    rotime[i]=`echo $line | awk {'print $6'}`
    echo -n "${pedir[i]} " >> ${prepFolder}/eddy/eddyIndex.txt
    if [ ${bval[i]} -eq 0 ]; then
	if [ ${pedir[i]} -eq 1 ]; then #LR
	    LRvols[idxLR]=$i
	    idxLR=$(($idxLR + 1))	
	elif [ ${pedir[i]} -eq 2 ]; then #RL
	    RLvols[idxRL]=$i
	    idxRL=$(($idxRL + 1))
	elif [ ${pedir[i]} -eq 3 ]; then #AP
	    APvols[idxAP]=$i
	    idxAP=$(($idxAP + 1))
	elif [ ${pedir[i]} -eq 4 ]; then #PA
	    PAvols[idxPA]=$i
	    idxPA=$(($idxPA + 1))
	fi
    else
	if [ ${pedir[i]} -eq 1 ]; then #LR
	    no_LR=$(($no_LR + 1))
	elif [ ${pedir[i]} -eq 2 ]; then #RL
	    no_RL=$(($no_RL + 1))
	elif [ ${pedir[i]} -eq 3 ]; then #AP
	    no_AP=$(($no_AP + 1))
	elif [ ${pedir[i]} -eq 4 ]; then #PA
	    no_PA=$(($no_PA + 1))
	fi
	if [ ${bval[i]} -eq 400 ]; then
	    idxb400=$(($idxb400+1))
	elif [ ${bval[i]} -eq 1000 ]; then
	    idxb1000=$(($idxb1000+1))
	elif [ ${bval[i]} -eq 2600 ]; then
	    idxb2600=$(($idxb2600+1))
	fi
    fi
    i=$(($i + 1))
    if [ $i -eq ${nVols} ]; then
	break
    fi
done < ${acqProt}


#============================================================================
# Write json file for QC
#============================================================================
echo "{" > ${prepFolder}/dataImport.json

echo "   \"no_B400_vols\": $idxb400," >> ${prepFolder}/dataImport.json
echo "   \"no_B1000_vols\": $idxb1000," >> ${prepFolder}/dataImport.json
echo "   \"no_B2600_vols\": $idxb2600," >> ${prepFolder}/dataImport.json

echo "   \"no_LR_vols\": $no_LR," >> ${prepFolder}/dataImport.json
echo "   \"no_RL_vols\": $no_RL," >> ${prepFolder}/dataImport.json
echo "   \"no_AP_vols\": $no_AP," >> ${prepFolder}/dataImport.json
echo "   \"no_PA_vols\": $no_PA" >> ${prepFolder}/dataImport.json

echo "}" >> ${prepFolder}/dataImport.json


#============================================================================
# Write bvecs, bvals and eddy acquisition parameters file.
#============================================================================
echo "${bvec_x[@]}" > ${prepFolder}/tmpData/bvecs
echo "${bvec_y[@]}" >> ${prepFolder}/tmpData/bvecs
echo "${bvec_z[@]}" >> ${prepFolder}/tmpData/bvecs
echo "${bval[@]}" > ${prepFolder}/bvals

if [ $LRvols -ne -1 ]; then
    echo -1 0 0 ${rotime[${LRvols[0]}]} > ${prepFolder}/eddy/acqparamsUnwarp.txt
else
    echo -1 0 0 0.05 > ${prepFolder}/eddy/acqparamsUnwarp.txt
fi
if [ $RLvols -ne -1 ]; then
    echo 1 0 0 ${rotime[${RLvols[0]}]} >> ${prepFolder}/eddy/acqparamsUnwarp.txt
else
    echo 1 0 0 0.05 >> ${prepFolder}/eddy/acqparamsUnwarp.txt
fi
if [ $APvols -ne -1 ]; then
    echo 0 -1 0 ${rotime[${APvols[0]}]} >> ${prepFolder}/eddy/acqparamsUnwarp.txt
else
    echo 0 -1 0 0.05 >> ${prepFolder}/eddy/acqparamsUnwarp.txt
fi
if [ $PAvols -ne -1 ]; then
    echo 0 1 0 ${rotime[${PAvols[0]}]} >> ${prepFolder}/eddy/acqparamsUnwarp.txt
else
    echo 0 1 0 0.05 >> ${prepFolder}/eddy/acqparamsUnwarp.txt
fi

#============================================================================
# Reorient raw data and bvecs to standard orientations
#============================================================================
${FSLDIR}/bin/fslreorient2std ${dataFolder}/${dataFile} ${prepFolder}/tmpData/data
${FSLDIR}/bin/fslreorient2std ${dataFolder}/${dataFile} > ${prepFolder}/tmpData/raw2std.mat

echo 1 0 0 0 > ${prepFolder}/tmpData/flipZ.mat
echo 0 1 0 0 >> ${prepFolder}/tmpData/flipZ.mat
echo 0 0 -1 0 >> ${prepFolder}/tmpData/flipZ.mat
echo 0 0 0 1 >> ${prepFolder}/tmpData/flipZ.mat

${scriptsFolder}/utils/rotateBvecs.sh ${prepFolder}/tmpData/bvecs ${prepFolder}/tmpData/raw2std.mat ${prepFolder}/tmpData/bvecs2
${scriptsFolder}/utils/rotateBvecs.sh ${prepFolder}/tmpData/bvecs2 ${prepFolder}/tmpData/flipZ.mat ${prepFolder}/bvecs

#============================================================================
# Check that in-plane matrix size is a multiple of 2 (for TOPUP)
#============================================================================
dimt1=`${FSLDIR}/bin/fslval ${prepFolder}/tmpData/data dim1`
c1=$(($dimt1%2))
if [ $c1 -ne 0 ]; then
    ${FSLDIR}/bin/fslroi ${prepFolder}/tmpData/data ${prepFolder}/tmpData/tmp 0 1 0 -1 0 -1 0 -1
    ${FSLDIR}/bin/fslmerge -x ${prepFolder}/tmpData/data ${prepFolder}/tmpData/data ${prepFolder}/tmpData/tmp
fi
dimt2=`${FSLDIR}/bin/fslval ${prepFolder}/tmpData/data dim2`
c2=$(($dimt2%2))
if [ $c2 -ne 0 ]; then
    ${FSLDIR}/bin/fslroi ${prepFolder}/tmpData/data ${prepFolder}/tmpData/tmp 0 -1 0 1 0 -1 0 -1
    ${FSLDIR}/bin/fslmerge -y ${prepFolder}/tmpData/data ${prepFolder}/tmpData/data ${prepFolder}/tmpData/tmp
fi


#============================================================================
# Identify best b0s for every acquired PE direction
#============================================================================
echo "${LRvols[@]}" > ${prepFolder}/topup/b0Indices
echo "${RLvols[@]}" >> ${prepFolder}/topup/b0Indices
echo "${APvols[@]}" >> ${prepFolder}/topup/b0Indices
echo "${PAvols[@]}" >> ${prepFolder}/topup/b0Indices

if [ $LRvols -ne -1 ]; then 
    tmp=$(printf ",%s" "${LRvols[@]}")
    tmp=${tmp:1}
    ${FSLDIR}/bin/fslselectvols -i ${prepFolder}/tmpData/data -o ${prepFolder}/topup/LR_B0s --vols=${tmp}
    $scriptsFolder/utils/pickBestB0s.sh ${prepFolder}/topup 0 ${noB0s}
fi
if [ $RLvols -ne -1 ]; then 
    tmp=$(printf ",%s" "${RLvols[@]}")
    tmp=${tmp:1}
    ${FSLDIR}/bin/fslselectvols -i ${prepFolder}/tmpData/data -o ${prepFolder}/topup/RL_B0s --vols=${tmp}
    $scriptsFolder/utils/pickBestB0s.sh ${prepFolder}/topup 1 ${noB0s}
fi
if [ $APvols -ne -1 ]; then 
    tmp=$(printf ",%s" "${APvols[@]}")
    tmp=${tmp:1}
    ${FSLDIR}/bin/fslselectvols -i ${prepFolder}/tmpData/data -o ${prepFolder}/topup/AP_B0s --vols=${tmp}
    $scriptsFolder/utils/pickBestB0s.sh ${prepFolder}/topup 2 ${noB0s}
fi
if [ $PAvols -ne -1 ]; then 
    tmp=$(printf ",%s" "${PAvols[@]}")
    tmp=${tmp:1}
    ${FSLDIR}/bin/fslselectvols -i ${prepFolder}/tmpData/data -o ${prepFolder}/topup/PA_B0s --vols=${tmp}
    $scriptsFolder/utils/pickBestB0s.sh ${prepFolder}/topup 3 ${noB0s}
fi


#============================================================================
# Sort b0s based on their scores, merge them in a file and write acqparams
# for topup and reference scan for eddy.
#============================================================================
bestPE=(`cat ${prepFolder}/topup/idxBestB0s.txt | sort -k 3 -n | head -n 4 | awk '{print $1}'`)
bestVol=(`cat ${prepFolder}/topup/idxBestB0s.txt | sort -k 3 -n | head -n 4 | awk '{print $2}'`)

acqpPE=("-1 0 0" "1 0 0" "0 -1 0" "0 1 0")
PE=("LR" "RL" "AP" "PA")
count=0
echo -n > ${prepFolder}/topup/acqparams.txt
for i in "${bestPE[@]}" ; do
    dimt4=`${FSLDIR}/bin/fslval ${prepFolder}/topup/"${PE[$i]}"_B0s.nii.gz dim4`
    for j in $(seq 0 $((${dimt4}-1))) ; do 
	echo "${acqpPE[$i]}" "${rotime[${bestVol[${count}]}]}" >> ${prepFolder}/topup/acqparams.txt
    done
    PE_B0s[$count]=${prepFolder}/topup/"${PE[$i]}"_B0s.nii.gz
    count=$(($count+1))
done
echo ${PE_B0s[@]}
${FSLDIR}/bin/fslmerge -t ${prepFolder}/topup/phase ${PE_B0s[@]}


echo "${bestVol[0]}" > ${prepFolder}/eddy/ref_scan.txt


echo -e "\n END: Importing files"

