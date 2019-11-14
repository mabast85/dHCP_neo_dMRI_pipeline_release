#!/bin/bash

echo "\n START: dHCP neonatal dMRI data processing pipeline"


if [ "${2}" == "" ];then
    echo "The script will read dHCP subject info and, if data is there, launch the processing steps"
    echo ""
    echo "usage: dHCP_neo_dMRI_launchPipeline.sh <subject list> <output folder>"
    echo ""
    echo "       subject list: text file containing participant_id, sex and age at birth (w GA)"
    echo "       output folder: folder where results will be stored"
    echo ""
    echo ""
fi

subjList=$1
outFolder=$2


mkdir -p ${outFolder}

# Read the connectome IDs
sids=(`cat ${subjList} | sed "1 d" | cut -f 1 | grep -v "^$"`)

# Main loop through subjects
for s in ${sids[@]}; do

    sex=`cat ${subjList} | grep ${s} | cut -f 2`
    birth=`cat ${subjList} | grep ${s} | cut -f 3`   # Age at birth (weeks)
    sessions=(`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | sed "1 d" | cut -f 1 | grep -v "^$"`)   # Some subjects are acquired over multiple sessions
    n_sessions=`echo ${#sessions[@]}`

    if [ ${n_sessions} -gt 0 ]; then	
	for ses in ${sessions[@]}; do
	    date=`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | grep ${ses} | cut -f 2`
	    age=`cat ${reconFolder}/sub-${s}/sub-${s}_sessions.tsv | grep ${ses} | cut -f 3`   # Age at scan (weeks)

	    # Round birth and scan ages
	    age=`awk -v v="${age}" 'BEGIN{printf "%.0f", v}'`
	    birth=`awk -v v="${birth}" 'BEGIN{printf "%.0f", v}'`

	    # Subject specific variables
	    data=${reconFolder}/sub-${s}/ses-${ses}/DWI/sub-${s}_ses-${ses}_DWI_MB0_AnZfZfAdGhAb.nii
	    t2=${structFolder}/sub-${s}/ses-${ses}/anat/sub-${s}_ses-${ses}_T2w_restore.nii.gz
	    seg=${structFolder}/sub-${s}/ses-${ses}/anat/sub-${s}_ses-${ses}_drawem_tissue_labels.nii.gz

	    if [ -e ${data} ]; then   # Check that data has been acquired
		#============================================================================
		# Check for scan completeness
		#============================================================================
		dimt4=`${FSLDIR}/bin/fslval ${data} dim4`
		complete_check=${dimt4}
		usable_check=1
		if [ ${dimt4} -lt 34 ]; then
		    echo "WARNING: The dataset is unusable as it does not contain enough b0 volumes"
		    echo "${s} ses-${ses}" >> ${outFolder}/unusable.txt
		    usable_check=0
		elif [ ${dimt4} -lt 123 ]; then
		    echo "WARNING: The dataset is incomplete and does not contain enough b0 pairs for each PE direction"
		    echo "${s} ses-${ses}" >> ${outFolder}/incomplete.txt
		    noB0s=1
		    usable_check=1
		fi

		#============================================================================
		# Store QC information
		#============================================================================
		subjOutFolder=${outFolder}/${s}/ses-${ses}
		if [ -e ${subjOutFolder}/initQC.json ]; then
		    break
		fi
		mkdir -p ${subjOutFolder}
		echo "{" > ${subjOutFolder}/initQC.json
		echo "   \"Complete\": ${complete_check}," >> ${subjOutFolder}/initQC.json
		echo "   \"Usable\": ${usable_check}," >> ${subjOutFolder}/initQC.json
		echo "   \"nSessions\": ${n_sessions}," >> ${subjOutFolder}/initQC.json
		echo "   \"birthAge\": ${birth}," >> ${subjOutFolder}/initQC.json
		echo "   \"scanAge\": ${age}" >> ${subjOutFolder}/initQC.json
		echo "}" >> ${subjOutFolder}/initQC.json

		if [ -e ${t2} ]; then # Check that structural data has been acquired
		    #============================================================================
		    # Set processing jobs
		    #============================================================================
		    ${scriptsFolder}/dHCP_neo_dMRI_setJobs.sh ${reconFolder}/sub-${s} ses-${ses} sub-${s}_ses-${ses}_DWI_MB0_AnZfZfAdGhAb.nii ${s} \
		    		    ${scriptsFolder}/dHCP_protocol.txt ${scriptsFolder}/slorder.txt ${outFolder} \
				    ${age} ${birth} ${t2} ${seg} 1 1

		    echo "${s} ${ses} ${birth} ${age}" >> ${outFolder}/complete.txt
		    
		else
		    echo "WARNING! Missing structural data for subject ${s}"
		    echo "${s} ses-${ses}" >> ${outFolder}/missingAnat.txt
		fi
	    else
		echo "WARNING! Missing dMRI data for subject ${s}"
		echo "${s} ses-${ses}" >> ${outFolder}/missingDmri.txt
	    fi
	    
	done
    else
	echo "WARNING! Missing session IDs for subject ${s}"
	echo "${s}" >> ${outFolder}/missingSessions.txt
    fi

done


echo "\n END: dHCP neonatal dMRI data processing pipeline"
