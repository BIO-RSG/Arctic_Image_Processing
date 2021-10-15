# Make daily composite images

# Make daily composites using the median of all images available in (per pixel)
grdpath = "../data/GRD/" # where the GRD files to composite are. This script assue folder structure is GRD/year/day
mapjpgpath = "./" # where script is to make maps
writefiles = "../data/Composites/1day"

library(ncdf4)
library(stringr)
library(sp)

###########
combine_function = "median" # "median", "mean", etc. See line 114
var_code <- "han" # Variable to find data for "sst", "dox","han" etc based on file extension
albedo_box = FALSE # TRUE = crop high albedo to box area, FALSE = Shapefile boundary of high albedo processing
if (albedo_box) {
  latmin = 68.7
  latmax = 69.3
  lonmin = -138.9
  lonmax = -133.4
}
print(paste("PROCESSING DAILY COMPOSITES FOR:",var_code)) 
print(paste("USING:", combine_function,
            "with", ifelse(albedo_box == TRUE, "box crop for raised albedo", 
                           "polygon crop for raised albedo")))

###########

for (iyear in 2020:2021) {
  lifiday = list.files(paste0(grdpath,iyear), full.names = T)
  nbday=length(lifiday)

  # Open the first image in the list to retrieve lat/lon info
  # vector to matrices for lat and lon
  img_name = list.files(lifiday[1], pattern = var_code)[1] #Grab first image in list
  ncf = nc_open(paste0(lifiday[1], "/", img_name))
  longi = ncvar_get(ncf,"lon")
  lati = ncvar_get(ncf,"lat")
  nc_close(ncf)
  matlon = matrix(rep(longi,length(lati)),length(longi),length(lati))
  matlat = t(matrix(rep(lati,length(longi)),length(lati),length(longi)))
  dim(matlon)
  
  if (albedo_box) {
    reg = data.frame(long = c(lonmin, lonmax, lonmax, lonmin, lonmin),
                     lat = c(latmax, latmax, latmin, latmin, latmax))
    mask = point.in.polygon(matlon, matlat, reg$long, reg$lat)
  } else {
    # Loading shapefile mask and saving as .rds:
    # reg1 <- rgdal::readOGR("Region_1_buffer.shp")
    # reg1 <- ggplot2::fortify(reg1)
    # mask = point.in.polygon(matlon, matlat, reg1$long, reg1$lat)
    # saveRDS(object = mask, file = "Reg_1_mask.rds")
    mask=readRDS("Reg_1_mask.rds")
  }
  
  for (i in 1:nbday)
  {
    print(paste(iyear, ":", i,"of", nbday, sep = " "))
    lifim = list.files(lifiday[i],pattern = paste0(var_code, ".grd"), full.names = T)
    if (length(lifim)>0) { # Check if folder is empty
      print(length(lifim))
      lifim_sub = list.files(lifiday[i],pattern = paste0(var_code, ".grd"))
      yearday = unique(substr(lifim_sub,2,8))
      time = substr(lifim_sub,9,12) 
      # If time filter wanted:
      # time_idx = time >= 1630
      # lifim=lifim[time_idx]
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
        outfile=paste0("A",yearday,var_code,".asc")
        write.table(cbind(matlon[indk],matlat[indk],medgeovar[indk]),outfile,
              row.names=F,col.names=F,quote=F)
        
        grdfile=paste0("A",yearday,var_code,".grd")
        cmdgrd=paste("gmt xyz2grd ",outfile," -G",grdfile," -I1100e -R/-142/-110/67.5/76 -V",sep="")
        system(cmdgrd)
        if (var_code == "dox" | var_code == "han") {
          cmdgmt=paste0(mapjpgpath,"gmt_spm_daily_composite.sh ", substr(grdfile,1,10))
        } 
        system(cmdgmt)
        #system("rm *ps")
      } else {
        print("No images in time frame")
      }
      } else {
        print("No images in folder")
      } 
    }
}
