#!/bin/bash

set -e
echo -e "\n Running topup..."


topupDir=$1   # Folder where input files are and where output will be stored

topupConfigFile=${FSLDIR}/etc/flirtsch/b02b0.cnf


#============================================================================
# Run topup on the selected b0 volumes.
#============================================================================
${FSLDIR}/bin/topup --imain=${topupDir}/phase --datain=${topupDir}/acqparams.txt --config=${topupConfigFile} --fout=${topupDir}/fieldmap --iout=${topupDir}/topup_b0s --out=${topupDir}/topup_results -v


#============================================================================
# Run bet on average iout.
#============================================================================
echo "Running BET on the hifi b0"
${FSLDIR}/bin/fslmaths ${topupDir}/topup_b0s -Tmean ${topupDir}/topup_hifib0
${FSLDIR}/bin/bet ${topupDir}/topup_hifib0 ${topupDir}/nodif_brain -m -f 0.25 -R


echo -e "\n END: runTopup."

