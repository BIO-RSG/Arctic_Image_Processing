#!/bin/bash
# Steps to process L2 to month composites

# 0. Study area: 
lonmax=-110
lonmin=-142
latmax=76
latmin=67.5

# Notes:
# - Before processing, to check minimum number of pixels in L2 image can uncomment the following (or change line 149 in compute_spm_modisa.py):

#for l2name in ./data/A*.L2;
#do
#	Rscript ./scripts/Check_nb_pixel_in_image.R $l2name $lonmax $lonmin $latmax $latmin
#   	read -r nbvalpix < nbvalpxl.asc
#	echo $nbvalpix
#	if [ $nbvalpix -lt 100 ]; then
#		echo "not enough pixels"
#		mv $l2name ../ # For now just moving file if not enough pixels
#	fi
#	nbvalpix=""
#done

#### 1. ####
# L2 NASA flags, q/c and calculate SPM for all L2 files in 'data' directory:
for l2name in ./data/A*.L2;
do
python ./scripts/compute_spm_modisa.py ${l2name:0:-3};
done

#### 2. ####
# Grid files with GMT at 1100 m resolution
# (300 m used for 250 MODISA processing)
for ascname in ./data/*griddata.asc; 
do
gmt xyz2grd $ascname -G${ascname:0:-4}spmhan.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
gmt xyz2grd -i,0,1,3 $ascname -G${ascname:0:-4}spmdox.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,4 $ascname -G${ascname:0:-4}sst.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,5 $ascname -G${ascname:0:-4}par.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
done

#### 2a. ####
# Make jpgs - here doing just for SPM Han
echo "making jpgs for l2"
for grdname in ./data/*spmhan.grd;
do
bash ./scripts/map_spm_L2.sh ${grdname:0:-4};
done

#### 3. ####
# Make daily composites from L2 GRD files in ../data folder
mkdir -p ./data/Composites/daily
echo "making daily comps"
Rscript ./scripts/make_daily_composites_modisa.R

#### 4. ####
# Make month composites from the daily composites in ../data/Composites/daily
mkdir -p ./data/Composites/monthly
Rscript ./scripts/make_month_composites_modisa.R

####
# Clean up 
rm ./data/Composites/daily/*.ps
rm ./data/Composites/monthly/*.ps
rm ./data/*.ps
rm gmt.conf
rm gmt.history
rm spm.cpt

mkdir -p ./data/ASC/
mkdir -p ./data/GRD/
mkdir -p ./data/JPG/
mv ./data/*.asc ./data/ASC/
mv ./data/*.grd ./data/GRD/
mv ./data/*.jpg ./data/JPG/

