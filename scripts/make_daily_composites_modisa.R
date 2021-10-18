# Make daily composite images

# Make daily composites using the median of all images available in (per pixel)
grdpath = "../data" # where the GRD files to composite are. This script assue folder structure is GRD/year/day
mapjpgpath = "./" # where script is to make maps
writefiles = "../data/Composites/daily"

library(ncdf4)
library(stringr)
library(sp)

###########
combine_function = "median" # "median", "mean", etc. See line 114
var_code = "dox" # Variable to find data for "sst", "dox","han" etc based on file extension
albedo_box = TRUE # TRUE = crop high albedo to box area, FALSE = Shapefile boundary of high albedo processing
if (albedo_box) {
  latmin_a = 68.7
  latmax_a = 69.3
  lonmin_a = -138.9
  lonmax_a = -133.4
}
lonmax=-110
lonmin=-142
latmax=76
latmin=67.5
print(paste("PROCESSING DAILY COMPOSITES FOR:",var_code)) 
print(paste("USING:", combine_function,
            "with", ifelse(albedo_box == TRUE, "box crop for raised albedo", 
                           "polygon crop for raised albedo")))

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
  
if (albedo_box) {
  reg = data.frame(long = c(lonmin_a, lonmax_a, lonmax_a, lonmin_a, lonmin_a),
                   lat = c(latmax_a, latmax_a, latmin_a, latmin_a, latmax_a))
  mask = point.in.polygon(matlon, matlat, reg$long, reg$lat)
} else {
  # Loading shapefile mask and saving as .rds:
  # reg1 <- rgdal::readOGR("Region_1_buffer.shp")
  # reg1 <- ggplot2::fortify(reg1)
  # mask = point.in.polygon(matlon, matlat, reg1$long, reg1$lat)
  # saveRDS(object = mask, file = "Reg_1_mask.rds")
  mask=readRDS("Reg_1_mask.rds")
}
  
for (i in 1:length(nbday))
{
  print(paste(i,"of", length(nbday), sep = " "))
  lifim = lifiday[datestr==nbday[i]]
  nbim=length(lifim)
  if (nbim>0) {
    cubespm = array(NaN,c(length(longi),length(lati),nbim))
    for (j in 1:nbim)
    {
      #Open file
      isdelta <- str_extract(lifim[j],pattern="delta")
      ncf = nc_open(lifim[j])
      geovar=ncvar_get(ncf,"z")
      nc_close(ncf)
      print(dim(geovar))
      # Remove lat/lon out of range for delta files
      if (!is.na(isdelta) & (isdelta == "delta")) {
        print("delta file")
        isdelta=TRUE
        #use shapefile mask
        if ((dim(geovar)[1] == dim(matlat)[1]) & (dim(geovar)[2] == dim(matlat)[2])) {
          geovar[mask==0] <- NA
        } else {
          print("DELTA MASK WRONG SIZE")
        }
      } else if (is.na(isdelta) == TRUE) {
        print("full region file")
        isdelta = FALSE
      } else {
        print("ERROR WITH FILETYPE")
        break
      }
      #Remove data out of range for variable
      if ((var_code == "chl") || (var_code == "gsm") || (var_code == "aoemp")) {
        geovar[geovar < 0.01] <- NA # Remove chl pixels <0.05 and >40 mg m^-3
        geovar[geovar > 40] <- NA
      } else if (var_code == "sst") {
        geovar[geovar < -1.89] <- NA
      } else if ((var_code == "kd490") || (var_code == "kdlee")) {
        geovar[geovar <= 0] <- NA
        geovar[geovar >= 100] <- NA
      } else if (var_code == "kdlee") {
        geovar[geovar <= 0] <- NA
        geovar[geovar >= 100] <- NA
      } else if ((var_code == "han") || (var_code == "dox")) {
        geovar[geovar <= 0] <- NA # Need to set minimum value
        geovar[geovar > 1000] <- NA
      }
      cubespm[,,j] = geovar
    }
    medgeovar=apply(cubespm,c(1,2), combine_function, na.rm=T) 
    indk=is.finite(medgeovar)
    
    # Write out GRD files
    outfile=paste0(writefiles,"/A",nbday[i],var_code,".asc")
    write.table(cbind(matlon[indk],matlat[indk],medgeovar[indk]),outfile,
          row.names=F,col.names=F,quote=F)
    
    grdfile=paste0(writefiles,"/A",nbday[i],var_code,".grd")
    cmdgrd=paste0("gmt xyz2grd ",outfile," -G",grdfile," -I1100e -R/",lonmin,"/",lonmax,"/",latmin,"/",latmax," -V")
    system(cmdgrd)
    if (var_code == "dox" | var_code == "han") {
      cmdgmt=paste0("bash ",mapjpgpath,"map_spm_daily_composite.sh ", substr(grdfile,1,nchar(grdfile)-4))
    } 
    system(cmdgmt)
    #system("rm *ps")
  } else {
    print("No images in time frame")
  } 
}
