-----------------------------------------------
dHCP neonatal dMRI data processing pipeline
March, 2018

V 0.0.1: Pipeline reflecting the first data release processing
-----------------------------------------------
Comprehensive and automated pipeline to consistently analyse neonatal dMRI data from the developing Human Connectome Project (dHCP).

If you use the pipeline in your work, please cite the following article:
Bastiani, M., Andersson, J., Cordero-Grande, L., Murgasova, M., Hutter, J., Price, A.N., Makropoulos, A., Fitzgibbon, S.P., Hughes, E., Rueckert, D., Victor, S., Rutherford, M., Edwards, A.D., Smith, S., Tournier, J.-D., Hajnal, J.V., Jbabdi, S., Sotiropoulos, S.N. (2018). Automated processing pipeline for neonatal diffusion MRI in the developing Human Connectome Project. NeuroImage. 


Installation
------------
The pipeline consists of several bash scripts.
Once it has been downloaded, the first thing to do is fill the correct paths into:
dHCP_neo_dMRI_setup.sh

The script needs to be run before launching the processing jobs.


-------------------------------------------
Examples
-------------------------------------------
To launch the pipeline for a single subject, use the following command:
${scriptsFolder}/dHCP_neo_dMRI_setJobs.sh ${rawDataFolder}/sub-${cid} ses-${no} ${rawDataFile} ${cid} ${scriptsFolder}/dhcp300_f.txt ${outFolder} ${age} ${birth} ${n_sessions}

This command will submit all the necessary scripts to process the raw dMRI data. The necessary inputs are:
${rawDataFolder}/sub-${cid}: Path to raw data
ses-${no}: Session number
${rawDataFile}: Raw data file name
${cid}: Connectome ID
${scriptsFolder}/dhcp300_f.txt: Protocol file
${outFolder}: Output folder
${age}: Age at scan (in rounded weeks)
${birth}: Age at birth (in rounded weeks)
${n_sessions}: Total number of scanning sessions for the same subject


-------------------------------------------
Non-dHCP data
-------------------------------------------
To convert a locally acquired dataset such that it can be used with the pipeline, use the command:
${scriptsFolder}/utils/getProtocol

By typing the command in a terminal, the necessary inputs will be shown.
The script will generate a raw data file and a protocol file that can be used with the pipeline.

