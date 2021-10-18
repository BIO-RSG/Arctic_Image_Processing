#!/bin/bash
# Andrea Hilborn 2021

lonmax=-110
lonmin=-142
latmax=76
latmin=67.5

echo "Box is: $lonmin to $lonmax and $latmax to $latmin"

gmt gmtset COLOR_FOREGROUND white COLOR_BACKGROUND white \
BASEMAP_TYPE plain

region=-R/$lonmin/$lonmax/$latmin/$latmax
J=-JS234/90/16c
gmt makecpt -V -Crainbow -T0.1/1000/1  -Qo -Z  > spm.cpt

filename=$1
filestr=`echo "$filename" | grep -oP "A[0-9]{13}"`
year=${filestr:1:4}
day=${filestr:5:3}
timestamp=${filestr:8:6}
echo $year $day $timestamp

# Make tmp file to map
#gmt xyz2grd ${filestr}griddata.asc -Gtmpspm.grd -I1100e -R/$lonmin/$lonmax/$latmin/$latmax -V
cp $filename tmpspm.grd
# Map
gmt grdview  tmpspm.grd -Cspm.cpt ${region} $J -K -V -Ts -P > ${filename}.ps
gmt pscoast  $region $J -B4g2/a2g2 -W  -Dh -G180/180/180 -K -O -P  >> ${filename}.ps
gmt psscale -D8c/13.5c+w9.5c/0.5c+h+jCT+m+e -O -K -Q -B2+l"SPM g m@+-3@+" -Cspm.cpt -P >> ${filename}.ps
gmt pstext -R0/24/0/30 -JX16/16 -G255/255/255 -O -V -N -P  << EOF >> ${filename}.ps
12.4 2.8 18 0 4 LCB $year $day ${timestamp:0:2}:${timestamp:2:2}:${timestamp:4:2}
EOF
# Print
gmt psconvert -A -E150 -Tj ${filename}.ps
rm tmpspm.grd
