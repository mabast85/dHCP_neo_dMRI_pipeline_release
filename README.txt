-----------------------------------------------
dHCP neonatal dMRI data processing pipeline
April, 2018

V 0.0.2: Processing pipeline used for the 2nd public release
-----------------------------------------------
Automated pipeline to consistently analyse neonatal dMRI data from the developing Human Connectome Project (dHCP).

If you use the pipeline in your work, please cite the following article:
Bastiani, M., Andersson, J.L.R., Cordero-Grande, L., Murgasova, M.,
Hutter, J., Price, A.N., Makropoulos, A., Fitzgibbon, S.P., Hughes,
E., Rueckert, D., Victor, S., Rutherford, M., Edwards, A.D., Smith,
S., Tournier, J.-D., Hajnal, J.V., Jbabdi, S., Sotiropoulos,
S.N. (2019). Automated processing pipeline for neonatal diffusion MRI
in the developing Human Connectome Project. NeuroImage, 185, 750-763. 


Installation
------------
The pipeline consists of several bash scripts that do not require any installation.

Once it has been downloaded and unpacked, the first thing to do is fill the necessary paths into the file:
setup.sh

After that, source the script from the terminal in the following way:
. setup.sh

The script needs to be run before launching the processing jobs.


Dependencies
------------
The dMRI neonatal pipeline mainly relies on:
- FSL 6.0.1 (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)

Additional dependencies are:
- The dHCP structural pipeline (https://github.com/BioMedIA/dhcp-structural-pipeline)
- ANTs (http://stnava.github.io/ANTs/): non-linear registration to template space
- Convert3D (http://www.itksnap.org/pmwiki/pmwiki.php?n=Convert3D.Documentation): convert ANTs to FNIRT warp fields
- IRTK (https://www.doc.ic.ac.uk/~dr/software/usage.html): super resolution


-------------------------------------------
dHCP data
-------------------------------------------
To launch the pipeline, use:
${scriptsFolder}/dHCP_neo_dMRI_launchPipeline.sh participants.tsv ${outFolder}

This command will submit all the necessary jobs to process the dHCP neonatal dMRI datasets.
The two inputs are:
participants.tsv: Subject list 
${outFolder}: Output folder


-------------------------------------------
Non-dHCP data
-------------------------------------------
To convert a non-dHCP dataset such that it can be used with the pipeline, use the command:
${scriptsFolder}/utils/getProtocol

By typing the command in a terminal, the necessary inputs will be shown.
The script will generate a raw data file and a protocol file that can be used with the pipeline.


Directory structure
-------------------
The pipeline expects the following structure for the input dMRI data:
/path/to/data
	/subject1
		/session-1
			/DWI
				/data.nii.gz
		/session-2
			/DWI
				/data.nii.gz
	/subject2
		/session-1
			/DWI
				/data.nii.gz
	.
	.
	.
	/subjectN
		/session-1
			/DWI
				/data.nii.gz

The getProtocol command can be used to obtain each individual's data.nii.gz 4D nifti volume. All of them will need to be placed in the correct subject/session/DWI folder. This directory structure accounts for the fact that data from a single subject can be acquired in multiple sessions.


Examples
--------
To launch the pipeline for a single subject, use the following command:
${scriptsFolder}/dHCP_neo_dMRI_setJobs.sh ${rawDataFolder}/sub-${cid} \
					  session-${no} \
					  ${rawDataFile} \
					  ${cid} \
					  ${scriptsFolder}/protocol.txt 
					  ${slspec} \
					  ${outFolder} \
					  ${age} \
					  ${birth} \
					  ${subjT2} \
					  ${subjSeg} \
					  ${srFlag} \
					  ${gpuFlag}

This command will submit all the necessary scripts to process the raw dMRI data. Typing the command in the terminal without any input will show the user guide.
The necessary inputs are:
${rawDataFolder}/sub-${cid}: Path to raw data
session-${no}: Session folder
${rawDataFile}: Raw data file name
${cid}: Connectome ID
${scriptsFolder}/protocol.txt: Protocol file
${slspec}: eddy slspec file (0 if not available)
${outFolder}: Output folder
${age}: Age at scan (in weeks, rounded)
${birth}: Age at birth (in weeks, rounded)
${subjT2}: Subject's anatomical T2-weighted volume
${subjSeg}: Subject's tissue segmentation
${srFlag}: super resolution flag (0=do not use super resolution, 1=use
super resolution)
${gpuFlag}: if you have an NVIDIA GPU, this will significantly speed processing time
and allow to use all the eddy features (i.e., slice-to-volume
correction, motion-by-susceptibility-induced distortions)


