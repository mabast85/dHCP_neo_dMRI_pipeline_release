#!/bin/bash


set -e
echo -e "\n START: runTopup"


if [ "$1" == "" ];then
    echo ""
    echo "usage: $0 <Subject folder>"
    echo "       Subject folder: Path to the main subject folder"
    echo ""
    exit 1
fi

subFolder=$1

rawFolder=${subFolder}/raw
prepFolder=${subFolder}/PreProcessed
topupFolder=${prepFolder}/topup

topupConfigFile=${scriptsFolder}/utils/b02b0.cnf    # Topup configuration file


unique_pedirs=(`cat ${rawFolder}/pedirs`)
if [ `echo ${#unique_pedirs[@]}` -gt 1 ]; then
    echo "More than 1 phase encoding direction detected. Running topup"
    #============================================================================
    # Run topup on the selected b0 volumes.
    #============================================================================
    ${FSLDIR}/bin/topup --imain=${topupFolder}/phase --datain=${topupFolder}/acqparams.txt --config=${topupConfigFile} \
                        --fout=${topupFolder}/fieldmap --iout=${topupFolder}/topup_b0s --out=${topupFolder}/topup_results -v


    #============================================================================
    # Run bet on average iout.
    #============================================================================
    echo "Running BET on the hifi b0"
    ${FSLDIR}/bin/fslmaths ${topupFolder}/topup_b0s -Tmean ${topupFolder}/topup_hifib0
    ${FSLDIR}/bin/bet ${topupFolder}/topup_hifib0 ${topupFolder}/nodif_brain -m -f 0.25 -R
else
    echo "Only 1 phase encoding direction detected. Skipping topup"
fi


echo -e "\n END: runTopup."

