#!/bin/bash

lonmax=-110
lonmin=-142
latmax=76
latmin=67.5

# Details:
# - To check number of pixels in L2 image can uncomment the following (or add min pixel count into compute_spm_modisa.py):

#for l2name in ../data/A*.L2;
#do
#	Rscript Check_nb_pixel_in_image.R $l2name $lonmax $lonmin $latmax $latmin
#   	read -r nbvalpix < nbvalpxl.asc
#	echo $nbvalpix
#	if [ $nbvalpix -lt 100 ]; then
#		echo "not enough pixels"
#		mv $l2name ../ # For now just moving file if not enough pixels
#	fi
#	nbvalpix=""
#done

# - compute SPM, and filter/grid other vars
# - grid with GMT, and map 

#### 1. ####
# L2 NASA flags, q/c and calculate SPM for all L2 files in 'data' directory:
for l2name in ../data/A*.L2;
do
python ./compute_spm_modisa.py ${l2name:0:-3};
done

#### 2. ####
# Grid files with GMT at 1100 m resolution
# (300 m used for 250 MODISA processing)
for ascname in ../data/*griddata.asc; 
do
gmt xyz2grd $ascname -G${ascname:0:-4}spmhan.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
gmt xyz2grd -i,0,1,3 $ascname -G${ascname:0:-4}spmdox.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,4 $ascname -G${ascname:0:-4}sst.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,5 $ascname -G${ascname:0:-4}par.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
done

#### 2a. ####
# Make jpgs - here doing just for SPM Han
for grdname in ../data/*spmhan.grd;
do
bash ./map_spm_L2.sh ${grdname:0:-10};
done

#### 3. ####
# Make daily composites from L2 GRD files in ../data folder
mkdir -p ../data/Composites/daily
Rscript ./make_daily_composites_modisa.R

#### 4. ####
# Make month composites from the daily composites in ../data/Composites/daily
mkdir -p ../data/Composites/monthly
Rscript ./make_month_composites_modisa.R

####
# Clean up 
rm ../data/Composites/daily/*.ps
rm ../data/Composites/monthly/*.ps
rm ../data/*.ps
rm gmt.conf
rm gmt.history
rm spm.cpt
