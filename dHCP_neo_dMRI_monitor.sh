#!/bin/bash

echo "\n START: dHCP neonatal dMRI data processing pipeline progress monitor"


if [ "${2}" == "" ];then
    echo "The script will read dHCP subject info and output csv file with completed processing steps and metadata"
    echo ""
    echo "usage: dHCP_neo_dMRI_monitor.sh <subject list> <output folder>"
    echo ""
    echo "       subject list: text file containing participant_id, sex and age at birth (w GA)"
    echo "       output folder: folder where results are stored"
    echo ""
    echo ""
fi

subjList=$1
outFolder=$2


echo "participant_id,gender,birth_ga,session_id,date,age_at_scan,dmri,T2,seg,pip_import,pip_topup,pip_eddy,pip_superres,pip_dki,pip_bpx,pip_reg" > ${outFolder}/monitor.csv


# Read the connectome IDs
sids=(`cat ${subjList} | sed "1 d" | cut -f 1 | grep -v "^$"`)

# Main loop through subjects
for s in ${sids[@]}; do
    # Set progress variables to 0
    sex=0
    birth=0
    date=0
    age=0
    dimt4=0
    dimt2=0
    dimseg=0
        
    sex=`cat ${subjList} | grep ${s} | cut -f 2`
    birth=`cat ${subjList} | grep ${s} | cut -f 3`   # Age at birth (weeks)
    sessions=(`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | sed "1 d" | cut -f 1 | grep -v "^$" | sort -u`)   # Some subjects are acquired over multiple sessions
    n_sessions=`echo ${#sessions[@]}`
    
    if [ ${n_sessions} -gt 0 ]; then	
	for ses in ${sessions[@]}; do

	    date=(`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | grep ${ses} | cut -f 2`)
	    age=(`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | grep ${ses} | cut -f 3`)   # Age at scan (weeks)

	    n=('n/a')
	    if [ `echo ${#sessions[@]}` -gt 1 ]; then
		date="${date[@]/$n}"
		age=${age[0]}
	    fi

	    # Subject specific variables
	    data=${reconFolder}/sub-${s}/ses-${ses}/DWI/sub-${s}_ses-${ses}_DWI_MB0_AnZfZfAdGhAb.nii
	    t2=${structFolder}/sub-${s}/ses-${ses}/anat/sub-${s}_ses-${ses}_T2w_restore.nii.gz
	    seg=${structFolder}/sub-${s}/ses-${ses}/anat/sub-${s}_ses-${ses}_drawem_tissue_labels.nii.gz

	    if [ -e ${data} ]; then   # Check that data has been acquired
		#============================================================================
		# Check for scan size
		#============================================================================
		dimt4=`${FSLDIR}/bin/fslval ${data} dim4 | tr -d '[:space:]'`

		if [ -e ${t2} ]; then # Check that structural data has been acquired
		    dimt2=1

		    if [ -e ${seg} ]; then
			dimseg=1

			subjOutFolder=${outFolder}/${s}/ses-${ses}
			# Check data import
			if [ -e ${subjOutFolder}/raw/data.nii.gz ]; then
			    p_import=1
			else
			    p_import=0
			fi
			# Check topup
			if [ -e ${subjOutFolder}/PreProcessed/topup/nodif_brain.nii.gz ]; then
			    p_topup=1
			else
			    p_topup=0
			fi
			# Check eddy
			if [ -e ${subjOutFolder}/PreProcessed/eddy/nodif_brain.nii.gz ]; then
			    p_eddy=1
			else
			    p_eddy=0
			fi
			# Check superres
			if [ -e ${subjOutFolder}/Diffusion/data.nii.gz ]; then
			    p_superres=1
			else
			    p_superres=0
			fi
			# Check dki
			if [ -e ${subjOutFolder}/Diffusion/dkifit/dki_S0.nii.gz ]; then
			    p_dki=1
			else
			    p_dki=0
			fi
			# Check bpx
			if [ -e ${subjOutFolder}/Diffusion.bedpostX/dyads1.nii.gz ]; then
			    p_bpx=1
			else
			    p_bpx=0
			fi
			# Check reg
			if [ -e ${subjOutFolder}/Diffusion/xfms/std40w2diff_warp.nii.gz ]; then
			    p_reg=1
			else
			    p_reg=0
			fi
			
			echo "${s},${sex},${birth},${ses},${date},${age},${dimt4},${dimt2},${dimseg},${p_import},${p_topup},${p_eddy},${p_superres},${p_dki},${p_bpx},${p_reg}" >> ${outFolder}/monitor.csv
		    fi
		fi
	    fi
	done
    fi
done


echo "\n END: dHCP neonatal dMRI data processing pipeline progress monitor"
