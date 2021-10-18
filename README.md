## Arctic Image Processing

Processing scripts for the AO / Beaufort Sea datasets.

Scripts here currently for L2 MODISA and above.

### Software:
* R (packages ncdf4, stringr, sp)
* Python (v3 with numpy and netCDF4)
* GMT 

### Steps:

If you place all L2 files to be processed in the `./data` folder, you should not have to change file paths. Test files included in data folder are `./data/A2020241203000.L2` and `./data/A2020241203000delta.L2`

**`01_L2_to_Composite.sh`** runs all steps to process L2 files to monthly composites. 

#### 01_L2_to_Composite.sh:

0. Specify your study area 

1. Runs `./scripts/compute_spm_modisa.py` to implement L2 NASA flags, other q/c, calculate SPM
  * Modify the L2 NASA flags you want to use: `line 16: l2_flags_to_use=`
  * If you do not have a solar zenith angle layer in your file, specify `line 17: solz_layer=False`
  * If you DO have a solar zenith angle layer (`solz`) you can change the maximum angle on `line 18`
  
2. Grid files using GMT 
  * Grids the .asc files produced from `./scripts/compute_spm_modisa.py`, here at 1100 m resolution (`-I1100`)
  * Writes out .jpg files of each L2 image using `./scripts/map_spm_L2.sh`
  
3. Make daily composites with `./scripts/make_daily_composites_modisa.R`
  * We have used the `median` to combine, but can specify a different function on `line 14`
  * Variable to composite on `line 19`
  * Options for raised albedo processing files (finds files with `delta` in filename from our processing) are to crop to a box (`line 21 - line 25`) **OR** crop using a shapefile (see `line 58`)
  * This script makes daily composite .jpgs with GMT using `./scripts/map_spm_daily_composite.sh`. If not wanted set `line 18: make_jpgs=FALSE`
  
4. Make monthly composites with `./scripts/make_month_composites_modisa.R` from files in `./data/Composites/daily` by cycling through dates in filename 
  * Specify combine function on `line 14`, var on `line 19` and bounding box `line 20 - line 23`
  * Makes monthly composite .jpgs with GMT using `./scripts/map_spm_month_composite.sh` if `line 18: make_jpgs=TRUE`

