#!/bin/bash
set -e
echo -e "\n START: runEddy"


prepFolder=$1
dataFile=$2

topupFolder=${prepFolder}/topup
eddyFolder=${prepFolder}/eddy

ref_scan=`cat ${eddyFolder}/ref_scan.txt`

${FSLDIR}/bin/eddy_cuda --imain=${dataFile} --mask=${topupFolder}/nodif_brain_mask.nii.gz --index=${eddyFolder}/eddyIndex.txt --bvals=${prepFolder}/bvals --bvecs=${prepFolder}/bvecs --acqp=${eddyFolder}/acqparamsUnwarp.txt --topup=${topupFolder}/topup_results --out=${eddyFolder}/eddy_corrected --very_verbose --niter=5 --fwhm=10,5,0,0,0 --s2v_niter=10 --mporder=8 --nvoxhp=5000 --slspec=${scriptsFolder}/slorder.txt --repol --ol_type=both --s2v_interp=trilinear --s2v_lambda=1 --ref_scan_no=${ref_scan} --data_is_shelled --cnr_maps --residuals --dont_mask_output


#============================================================================
# Run bet on average iout.
#============================================================================
echo "Running BET on the hifi b0"
${FSLDIR}/bin/select_dwi_vols ${eddyFolder}/eddy_corrected ${prepFolder}/bvals ${eddyFolder}/hifib0 0 -m
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
bvals=($(head -n 1 ${prepFolder}/bvals))
eddyIndex=($(head -n 1 ${eddyFolder}/eddyIndex.txt))
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

# Compute average subject motion
#   m_abs: average absolute subject motion
#   m_rel: average relative subject motion
m_abs=0
m_rel=0
while read line
do
    # Read first column from EDDY output
    val=`echo $line | awk {'print $1'}`
    # To handle scientific notation, we need the following line
    val=`echo ${val} | sed -e 's/[eE]+*/\\*10\\^/'`
    m_abs=`echo "${m_abs} + ${val}" | bc -l`
    # Read second column from EDDY output
    val=`echo $line | awk {'print $2'}`
    # To handle scientific notation, we need the following line
    val=`echo ${val} | sed -e 's/[eE]+*/\\*10\\^/'`
    m_rel=`echo "${m_rel} + ${val}" | bc -l`
done < ${eddyFolder}/eddy_corrected.eddy_movement_rms
m_abs=`echo "${m_abs} / ${dimt4}" | bc -l`
m_rel=`echo "${m_rel} / ${dimt4}" | bc -l`

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
echo "   \"Avg_motion\": $m_abs" >> ${eddyFolder}/eddy_corrected.json
echo "}" >> ${eddyFolder}/eddy_corrected.json


echo -e "\n END: runEddy"

