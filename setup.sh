#!/bin/bash


echo "\n START: Setting up necessary folders to run the neonatal dMRI pipeline..."


# Folders where data and scripts are 
export scriptsFolder=/home/fs0/matteob/scripts/dHCP/dHCP_neoDMRI_pipeline   # neonatal dMRI pipeline scripts
export templateFolder=/vols/Data/baby/atlas/atlas-serag                     # Neonatal template folder

# dHCP-specific paths
export reconFolder=/vols/Data/baby/ownCloud/reconstructedImages/UpdatedReconstructions/ReconstructionsRelease03             # Raw data
export structFolder=/vols/Data/baby/ownCloud/derived_data/derived_v1.1_github/ReconstructionsRelease03/derivatives          # Structural pipeline outupt

# Folders where necessary programs are
export IRTKPATH=/home/fs0/matteob/scripts/dHCP/irtk-public/build/bin                # IRTK for super-resolution
export ants_scripts=/home/fs0/seanf/scratch/ANTs/ANTs/Scripts                       # ANTS scripts
export ANTSPATH=/home/fs0/seanf/scratch/ANTs/ANTs/bin/bin                           # ANTS binaries
export C3DPATH=/vols/Scratch/matteob/c3d/bin                                        # c3d to converts ANTS to FNIRT warps


echo "\n END: Setup complete"
