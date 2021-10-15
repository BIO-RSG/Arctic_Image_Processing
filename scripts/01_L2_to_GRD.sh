#!/bin/bash

# Details:
# - Images have already been checked - 100 pixels for .L2 and 100 pixels in "plume" region for delta.L2 files

# - compute SPM, and filter/grid other vars
# - grid with GMT, and map 

lonmax=-110
lonmin=-142
latmax=76
latmin=67.5

# Calculate SPM in python for all L2 files in current directory: need numpy and netCDF4
for l2name in ../data/A*.L2;
do

python ./compute_spm_modisa.py ${l2name:0:-3};

done

#### Grid file in GMT at 1100 m resolution ####
#### (300 m used for 250 MODISA processing)
for ascname in ../data/*griddata.asc; 
do
gmt xyz2grd $ascname -G${ascname:0:-4}spmhan.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
gmt xyz2grd -i,0,1,4 $ascname -G${ascname:0:-4}spmdox.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,5 $ascname -G${ascname:0:-4}sst.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;
# gmt xyz2grd -i,0,1,6 $ascname -G${ascname:0:-4}par.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V;

# Make jpg for SPM Han
bash ./map_spm_L2.sh ${ascname:0:-4}
rm gmt.conf
rm gmt.history 
rm spm.cpt # Remove temporary map grid file
done

#### Move files ####
pathmodis=../data/MODIS
pathgrd=../data/GRD
pathjpg=../data/JPG
pathasc=../data/ASC

for l2name in ../data/A*.L2; 
do
year=${l2name:1:4};
day=${l2name:5:3};
echo $year $day;
ascname=${l2name:0:-3}griddata.asc
grdname=${l2name:0:-3}*.grd
jpgname=${l2name:0:-3}griddata.jpg
# Create output directory
#mkdir -p ${pathmodis}/$a{year}/${day};
mkdir -p ${pathgrd}/${year}/${day};
mkdir -p ${pathjpg}/${year}/${day};
mkdir -p ${pathasc}/${year}/${day};
# Move files
#mv $l2name ${pathmodis}/${year}/${day};
mv $grdname ${pathgrd}/${year}/${day};
mv $jpgname ${pathjpg}/${year}/${day};
mv $ascname ${pathasc}/${year}/${day};
done

mkdir -p ../data/Composites/1day
Rscript ./make_daily_composites_modisa.R
