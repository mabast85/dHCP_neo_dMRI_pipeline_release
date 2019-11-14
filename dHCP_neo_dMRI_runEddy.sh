#!/bin/bash


set -e
echo -e "\n START: runEddy"
date


if [ "$1" == "" ];then
    echo ""
    echo "usage: $0 <Subject folder> <slspec>"
    echo "       Subject folder: Path to the main subject folder"
	echo "       slspec: eddy slspec file"
    echo ""
    exit 1
fi


subFolder=$1
slspec=$2
gpuFlag=$3

rawFolder=${subFolder}/raw
prepFolder=${subFolder}/PreProcessed
topupFolder=${prepFolder}/topup
eddyFolder=${prepFolder}/eddy


#============================================================================
# Add the necessary options based on the actual protocol.
#============================================================================
cmd=""
if [ "${slspec}" != "0" ]; then
    echo "slspec file provided."
    cmd="${cmd} --slspec=${slspec}"
    if [ "${gpuFlag}" -eq "1" ]; then
	echo "GPU acceleration enabled; running s2v eddy"
	cmd="${cmd} --s2v_niter=10 --mporder=8 --s2v_interp=trilinear --s2v_lambda=1"
    fi
fi
if [ -e ${topupFolder}/topup_results_fieldcoef.nii.gz ]; then
    echo "topup output detected. Adding the results to eddy."
    cmd="${cmd} --topup=${topupFolder}/topup_results"
    if [ "${gpuFlag}" -eq "1" ]; then
	echo "Correcting for mot-by-susc interactions."
	cmd="${cmd} --estimate_move_by_susceptibility --mbs_niter=20 --mbs_ksp=10 --mbs_lambda=10"
    fi
else
    echo "topup output not detected. Extracting brain mask from raw b0s."
    ${FSLDIR}/bin/bet ${rawFolder}/data ${topupFolder}/nodif_brain -m -f 0.25 -R
fi

#============================================================================
# Pick eddy executable based on GPU acceleration
#============================================================================
if [ "${gpuFlag}" -eq "1" ]; then
    eddy_exec=${FSLDIR}/bin/eddy_cuda
else
    eddy_exec=${FSLDIR}/bin/eddy_openmp
fi


# Run eddy
${FSLDIR}/bin/eddy_cuda --imain=${rawFolder}/data --mask=${topupFolder}/nodif_brain_mask.nii.gz --index=${rawFolder}/eddyIndex.txt \
						--bvals=${rawFolder}/bvals --bvecs=${rawFolder}/bvecs --acqp=${eddyFolder}/acqparamsUnwarp.txt \
						--out=${eddyFolder}/eddy_corrected --very_verbose \
						--niter=5 --fwhm=10,5,0,0,0 --nvoxhp=5000 \
						--repol --ol_type=both  --ol_nstd=3 \
						${cmd} \
						--data_is_shelled --cnr_maps --residuals --dont_mask_output \
						


#============================================================================
# Run bet on average iout.
#============================================================================
echo "Running BET on the hifi b0"
${FSLDIR}/bin/select_dwi_vols ${eddyFolder}/eddy_corrected ${rawFolder}/bvals ${eddyFolder}/hifib0 0 -m
${FSLDIR}/bin/bet ${eddyFolder}/hifib0 ${eddyFolder}/nodif_brain -m -f 0.25 -R


#================
# Quality Control
#================
i=-1
n_ol_b400=0
n_ol_b1000=0
n_ol_b2600=0
n_ol_LR=0
n_ol_RL=0
n_ol_AP=0
n_ol_PA=0
bvals=($(head -n 1 ${rawFolder}/bvals))
eddyIndex=($(head -n 1 ${rawFolder}/eddyIndex.txt))
dimt3=`${FSLDIR}/bin/fslval ${eddyFolder}/eddy_corrected.nii.gz dim3`
dimt4=`${FSLDIR}/bin/fslval ${eddyFolder}/eddy_corrected.nii.gz dim4`

# Compute outlier stats
#   n_ol_sl: number of times slice n has been classified as an outlier
#   n_ol_vol: number of outlier slices in each volume
#   n_ol_b*: number of outlier slices for each b-value shell
#   n_ol_*: number of outlier slices for each phase encode direction
#   tot_ol: total number of outliers
while read line
do
    if [ $i -ge 0 ]; then
	#echo ${line}
	tmp=(${line})
	a=0
	for ((ii=0; ii<$dimt3; ii++)); do
	    a=$((${a}+${tmp[ii]}))
	    n_ol_sl[ii]=$((${n_ol_sl[ii]}+${tmp[ii]}))
	done
	n_ol_vol[i]=$a
	if [ ${bvals[i]} -eq 400 ]; then
	    n_ol_b400=$((${n_ol_b400}+${a}))
	elif [ ${bvals[i]} -eq 1000 ]; then
	    n_ol_b1000=$((${n_ol_b1000}+${a}))
	elif [ ${bvals[i]} -eq 2600 ]; then
	    n_ol_b2600=$((${n_ol_b2600}+${a}))
	fi
	if [ ${eddyIndex[i]} -eq 1 ]; then
	    n_ol_LR=$((${n_ol_LR}+${a}))
	elif [ ${eddyIndex[i]} -eq 2 ]; then
	    n_ol_RL=$((${n_ol_RL}+${a}))
	elif [ ${eddyIndex[i]} -eq 3 ]; then
	    n_ol_AP=$((${n_ol_AP}+${a}))
	elif [ ${eddyIndex[i]} -eq 4 ]; then
	    n_ol_PA=$((${n_ol_PA}+${a}))
	fi
    fi
    i=$(($i + 1))
done < ${eddyFolder}/eddy_corrected.eddy_outlier_map
tot_ol=$((${n_ol_b400}+${n_ol_b1000}+${n_ol_b2600}))

# Write .json file
echo "{" > ${eddyFolder}/eddy_corrected.json
echo "   \"Tot_ol\": $tot_ol," >> ${eddyFolder}/eddy_corrected.json
tmp=$(printf ", %s" "${n_ol_vol[@]}")
tmp=${tmp:2}
echo "   \"No_ol_volumes\": [$tmp]," >> ${eddyFolder}/eddy_corrected.json
tmp=$(printf ", %s" "${n_ol_sl[@]}")
tmp=${tmp:2}
echo "   \"No_ol_slices\": [$tmp]," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_b400\": $n_ol_b400," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_b1000\": $n_ol_b1000," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_b2600\": $n_ol_b2600," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_LR\": $n_ol_LR," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_RL\": $n_ol_RL," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_AP\": $n_ol_AP," >> ${eddyFolder}/eddy_corrected.json
echo "   \"No_ol_PA\": $n_ol_PA," >> ${eddyFolder}/eddy_corrected.json
echo "}" >> ${eddyFolder}/eddy_corrected.json


date
echo -e "\n END: runEddy"

