#!/bin/bash
set -e
echo -e "\n START: running BPX model 3..."


diffFolder=$1


#============================================================================
# Run BPX model 3
#============================================================================
${FSLDIR}/bin/bedpostx ${diffFolder} -n 3 -b 3000 -model 3 --Rmean=0.3


echo -e "\n END: runBPX"

