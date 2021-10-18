# Make daily composite images
# Emmanuel Devred / Andrea Hilborn 2020

# Make daily composites using the median of all images available in (per pixel)
grdpath = "../data/Composites/daily" # where the GRD files to composite are
mapjpgpath = "./" # where script is to make maps
writefiles = "../data/Composites/monthly"

library(ncdf4)
library(stringr)


########### PARAMS:
combine_function = "median" 
# "median", "mean", "sd", etc, or define own function here. 
# e.g. for pixel depth:
#combine_fuction = function(x,...) { sum(is.finite(x))}
make_jpgs=TRUE
var_code <- "han" # Variable to find data for "sst", "dox","han" etc based on file extension
lonmax=-110
lonmin=-142
latmax=76
latmin=67.5
print(paste("PROCESSING MONTHLY COMPOSITES FOR:",var_code, "using:"))
print(combine_function) 
###########
lifiday = list.files(paste0(grdpath), pattern = paste0(var_code,".grd"), full.names = T)
datestr = str_extract(string = lifiday, pattern = "[0-9]{7}")
daystr = as.numeric(substr(datestr,5,7))
yrstr = as.numeric(substr(datestr, 1, 4))
nbday = unique(datestr)

# Open the first image in the list to retrieve lat/lon info
# vector to matrices for lat and lon
ncf = nc_open(lifiday[1])
longi = ncvar_get(ncf,"lon")
lati = ncvar_get(ncf,"lat")
nc_close(ncf)
matlon = matrix(rep(longi,length(lati)),length(longi),length(lati))
matlat = t(matrix(rep(lati,length(longi)),length(lati),length(longi)))
dim(matlon)

# Using day of year for month start and end
s_month <- c(1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335)
e_month <- c(s_month[2:12] - 1, 366)

for (iyear in unique(yrstr)) {
  lifi_yr = lifiday[yrstr == iyear]
  daystr_yr = daystr[yrstr == iyear]
  for (imonth in 1:length(s_month)) {
    imgmonth = lifi_yr[(daystr_yr >= s_month[imonth]) & (daystr_yr <= e_month[imonth])]
    if (length(imgmonth) > 0) {
      cubespm = array(NaN,c(length(longi),length(lati),length(imgmonth)))
      for (j in 1:length(imgmonth)) {
        #Open file
        ncf = nc_open(imgmonth[j])
        geovar=ncvar_get(ncf,"z")
        nc_close(ncf)
        print(dim(geovar))
        # No range filtering here as was done in daily composite step
        cubespm[,,j] = geovar
      }
      medgeovar=apply(cubespm,c(1,2), combine_function, na.rm=T) 
      indk=is.finite(medgeovar)
      
      # Write out GRD files, number of available imgs in month
      outfile=paste0(writefiles,"/A", iyear, 
                     "_month", 
                     str_pad(imonth, width = 2, side = "left", pad = "0"), 
                     "_n",
                     str_pad(length(imgmonth), width = 2, side = "left", pad = "0"),
                     "_", var_code,".asc")
      write.table(cbind(matlon[indk],matlat[indk],medgeovar[indk]),outfile,
                  row.names=F,col.names=F,quote=F)
      
      grdfile=paste0(writefiles,"/A", iyear, 
                     "_month", 
                     str_pad(imonth, width = 2, side = "left", pad = "0"), 
                     "_n",
                     str_pad(length(imgmonth), width = 2, side = "left", pad = "0"),
                     "_", var_code,".grd")
      cmdgrd=paste0("gmt xyz2grd ",outfile," -G",grdfile," -I1100e -R/",lonmin,"/",lonmax,"/",latmin,"/",latmax," -V")
      system(cmdgrd)
      if (make_jpgs == TRUE) {
        if (var_code == "dox" | var_code == "han") {
          cmdgmt=paste0("bash ",mapjpgpath,"map_spm_month_composite.sh ", substr(grdfile,1,nchar(grdfile)-4))
        } 
        system(cmdgmt)
      }
    } else {
      print(paste("no images for:",iyear,imonth))
    }
  }
}


