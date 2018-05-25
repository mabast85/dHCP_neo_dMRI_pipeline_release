#!/bin/bash

set -e
echo -e "\n START: setup dHCP neonatal dMRI data processing pipeline"

#============================================================================
# Set paths to dHCP structural pipeline volumes/surfaces
#============================================================================
export scriptsFolder=...    # Path to pipeline scripts
export IRTKPATH=...         # Path to IRTK binaries
export templateFolder=...   # Path to T2 template (Serag et al., 2012)


#============================================================================
# Set paths to dHCP structural pipeline volumes/surfaces
#============================================================================
export t2Folder=...   # Path to T2-weighted volume 
export segFolder=...  # Path to tissue segmentations
export surfFolder=... # Path to surfaces
export dofsFolder=... # Path to warps and matrices from registration


echo -e "\n END: setup dHCP neonatal dMRI data processing pipeline"
