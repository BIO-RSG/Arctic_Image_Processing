# Arctic Image Processing

Processing scripts for the AO / Beaufort Sea datasets.

Scripts here currently for L2 MODISA and above.

Software:
* R (packages ncdf4, stringr, sp)
* Python (> v3 with numpy and netCDF4)
* GMT 

Steps:

`./scripts/01_L2_to_Composite.sh` has all steps to process L2 files to monthly composites. 
If you place all L2 files to be processed in the `./data` folder here, you do not need to change file paths. Example files here are `./data/A2020241203000.L2` and `./data/A2020241203000delta.L2`
Steps:

1. Runs `./scripts/compute_spm_modisa.py` to calculate SPM and other layers, implement L2 NASA flags and other q/c
  * Modify the flags you want `line 16: l2_flags_to_use=`
  * If you do not have a solar zenith angle layer, specify `line 17: solz_layer=FALSE`
  * If you do have a solar zenith angle layer (`solz`), specify the maximum angle on `line 18`
  
2. Grids files using GMT from .asc files produced from `compute_spm_modisa.py`
  * Writes out .jpg files of each L2 image using `map_spm_L2.sh`
  
3. Makes daily composites with `./scripts/make_daily_composites_modisa.R`
  * See "params" section. We have used the `median` to combine, but can specify another function on `line 13`
  * Options for raised albedo files (with `delta` in extension from our processing) are to crop to a box (`line 19 - line 23`) OR using a shapefile (see `line 58`)
  * This script makes daily composite .jpgs with GMT using `./scripts/map_spm_daily_composite.sh`. Comment out last section if not wanted
  
4. Makes monthly composites from files in "./data/Composites/daily" by cycling through dates in filename. 
  * Specify combine function on `line 14`, param on `line 19` and bounding box `line 20 - line 23
  * Makes monthly composite .jpgs with GMT using `./scripts/map_spm_month_composite.sh`

