#!/bin/bash


set -e
echo -e "\n START: Importing files"


if [ "$6" == "" ];then
    echo ""
    echo "usage: $0 <Data folder> <Data filename> <Output folder> <Acquisition protocol> <Number of volumes> <Number of b0s>"
    echo "       Data folder: Path to the data file"
    echo "       Data filename: File name for the raw data"
    echo "       Output folder: Path to the subject output folder"
    echo "       Acqusition protocol: Text file with acquisition parameters"
    echo "       Number of volumes: Number of acquired volumes"
    echo "       Number of b0s: Number of b0s from each phase encoding block to use when estimating the fieldmap"
    echo ""
    exit 1
fi


dataFolder=$1      # Path to data file
dataFile=$2        # Data file name
outFolder=$3       # Subject output folder
acqProt=$4         # Acquisition protcol
nVols=$5           # Number of acquired volumes
noB0s=$6           # Number of B0 volumes for each PE direction used to estimate distortions with TOPUP

prepFolder=${outFolder}/PreProcessed
rawFolder=${outFolder}/raw
mkdir -p ${rawFolder}/tmpData


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
bshells=(100000)
n_b=0
i=0

echo -n > ${rawFolder}/tmpData/eddyIndex.txt
while read line; do
    bvec_x[i]=`echo $line | awk {'print $1'}`
    bvec_y[i]=`echo $line | awk {'print $2'}`
    bvec_z[i]=`echo $line | awk {'print $3'}`
    bval[i]=`echo $line | awk {'print $4'}`
    pedir[i]=`echo $line | awk {'print $5'}`
    rotime[i]=`echo $line | awk {'print $6'}`
    echo -n "${pedir[i]} " >> ${rawFolder}/tmpData/eddyIndex.txt
    if [ ${bval[i]} -lt 100 ]; then      #b0
        first_b0=${i}
        if [ ${pedir[i]} -eq 1 ]; then   #LR
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
    else                                 #dw
        if [ ${pedir[i]} -eq 1 ]; then   #LR
            no_LR=$(($no_LR + 1))
        elif [ ${pedir[i]} -eq 2 ]; then #RL
            no_RL=$(($no_RL + 1))
        elif [ ${pedir[i]} -eq 3 ]; then #AP
            no_AP=$(($no_AP + 1))
        elif [ ${pedir[i]} -eq 4 ]; then #PA
            no_PA=$(($no_PA + 1))
        fi
    fi
    # Identify unique shells
    b_flag=0
    for ub in "${bshells[@]}"; do 
        j=`echo ${bval[i]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}' `  # Round bval
	    j=${j/.*}   
	    b_diff=`echo "${j} - ${ub}" | bc | awk ' { if($1>=0) { print $1} else {print $1*-1 }}'`
        if [ ${b_diff} -lt 100 ]; then
            b_flag=1
            break
        fi
    done
    if [ "${b_flag}" == 0 ]; then
        bshells[n_b]=${bval[i]}
        n_b=$((${n_b} + 1))
    fi

    i=$(($i + 1))
    if [ $i -eq ${nVols} ]; then
	    break
    fi
done < ${acqProt}

bshells=($(echo "${bshells[@]}" | tr ' ' '\n' | sort -n -u | tr '\n' ' '))
echo "${bshells[@]}" > ${rawFolder}/shells
echo "Found ${n_b} shells: ${bshells[@]} s/mm^2"
un_pedirs=(`echo "${pedir[@]}" | tr ' ' '\n' | sort -n -u | tr '\n' ' '`)
echo "${un_pedirs[@]}" > ${rawFolder}/pedirs


#============================================================================
# Write json file for QC
#============================================================================
echo "{" > ${prepFolder}/dataImport.json

echo "   \"no_LR_vols\": $no_LR," >> ${prepFolder}/dataImport.json
echo "   \"no_RL_vols\": $no_RL," >> ${prepFolder}/dataImport.json
echo "   \"no_AP_vols\": $no_AP," >> ${prepFolder}/dataImport.json
echo "   \"no_PA_vols\": $no_PA" >> ${prepFolder}/dataImport.json

echo "}" >> ${prepFolder}/dataImport.json


#============================================================================
# Write bvecs, bvals and eddy acquisition parameters file.
#============================================================================
echo "${bvec_x[@]}" > ${rawFolder}/tmpData/orig_bvecs
echo "${bvec_y[@]}" >> ${rawFolder}/tmpData/orig_bvecs
echo "${bvec_z[@]}" >> ${rawFolder}/tmpData/orig_bvecs
echo "${bval[@]}" > ${rawFolder}/tmpData/bvals

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
# Reorient raw data and bvecs to to match the approximate orientation 
# of the standard template images (MNI152)
#============================================================================
${FSLDIR}/bin/fslreorient2std ${dataFolder}/${dataFile} ${rawFolder}/tmpData/data
${FSLDIR}/bin/fslreorient2std ${dataFolder}/${dataFile} > ${rawFolder}/tmpData/raw2std.mat

${scriptsFolder}/utils/rotateBvecs.sh ${rawFolder}/tmpData/orig_bvecs ${rawFolder}/tmpData/raw2std.mat ${rawFolder}/tmpData/bvecs


#============================================================================
# If more than 1 PE direction has been acquired, Identify best b0s for each 
# PE direction; otherwise, set the first b0 as the reference volume.
#============================================================================
unique_pedirs=(`cat ${rawFolder}/pedirs`)
if [ `echo ${#unique_pedirs[@]}` -gt 1 ]; then
    echo "More than 1 phase encoding direction detected. Selecting best b0 volumes for topup"
    ${scriptsFolder}/utils/pickBestB0s ${rawFolder}/tmpData/data ${rawFolder}/tmpData/bvals ${rawFolder}/tmpData/eddyIndex.txt ${rotime[0]} ${noB0s} ${prepFolder}/topup
else
    echo "1 phase encoding direction detected. Setting first b0 as reference volume"
    echo "${first_b0}" > ${prepFolder}/topup/ref_b0.txt
fi


#============================================================================
# Sort raw data based on the selected reference volume
#============================================================================
${scriptsFolder}/utils/sortData ${rawFolder}/tmpData/data `cat ${prepFolder}/topup/ref_b0.txt` ${rawFolder} ${rawFolder}/tmpData/bvals ${rawFolder}/tmpData/bvecs ${rawFolder}/tmpData/eddyIndex.txt


#============================================================================
# Clean unnecessary files
#============================================================================
rm -rf ${rawFolder}/tmpData


echo -e "\n END: Importing files"

