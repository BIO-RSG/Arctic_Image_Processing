#! /usr/bin/env python
# Emmanuel Devred, 2019
# Modified by Andrea Hilborn, 2020

from numpy import *
import sys, os

sys.dont_write_bytecode = True

import numpy as np
from netCDF4 import Dataset

def main(*args):
  
  #### Define L2 flags and other q/c ####
  l2_flags_to_use = ["LAND","HISATZEN"]
  solz_max=74 # Filtering solz layer created in L2 processing 
                #- remove and use HISOLZEN if no solz layer
                #- also remove solz from line 105
  ####
  
  ifile=str(sys.argv[1])+'.L2'
  print(ifile)
  ofile=str(sys.argv[1])+'griddata.asc'
  nc = Dataset(ifile,'r')
  gd_group = nc.groups['geophysical_data']
  nav_group = nc.groups['navigation_data']
  longitude = asarray(nav_group.variables['longitude'])
  latitude = asarray(nav_group.variables['latitude'])
  
  # Flagging and Q/C 
  flaglayer = asarray(gd_group.variables['l2_flags'])
  solz = asarray(gd_group.variables['solz'])
  all_l2_flags = {"ATMFAIL": 1,
                "LAND": 2,
                "PRODWARN": 4,
                "HIGLINT": 8,
                "HILT": 16,
                "HISATZEN": 32,
                "COASTZ": 64,
                "spare": 128,
                "STRAYLIGHT": 256,
                "CLDICE": 512,
                "COCCOLITH": 1024,
                "TURBIDW": 2048,
                "HISOLZEN": 4096,
                "spare": 8192,
                "LOWLW": 16384,
                "CHLFAIL": 32768,
                "NAVWARN": 65536,
                "ABSAER": 131072,
                "spare": 262144,
                "MAXAERITER": 524288,
                "MODGLINT": 1048576,
                "CHLWARN": 2097152,
                "ATMWARN": 4194304,
                "spare": 8388608,
                "SEAICE": 16777216,
                "NAVFAIL": 33554432,
                "FILTER": 67108864,
                "spare": 134217728,
                "BOWTIEDEL": 268435456,
                "HIPOL": 536870912,
                "PRODFAIL": 1073741824,
                "spare": 2147483648}
  # Get the values of the user-selected flags.
  if len(l2_flags_to_use)==0:
      l2_flags = {}
  else:
      flags = l2_flags_to_use
      l2_flags = {}
      for flag in flags:
          # If too many commas used, ignore blank space between them.
          if not flag or flag.isspace(): continue
          flag = flag.strip()
          # Ignore duplicate flags.
          if flag in l2_flags.keys(): continue
          # Check if input is a valid l2 flag.
          if not flag in all_l2_flags.keys():
              sys.exit("".join(["Input error: unrecognized flag: ", flag]))
          l2_flags[flag] = all_l2_flags[flag]
  # Get the final value representing all selected flags.
  user_mask = sum(list(l2_flags.values()))
  # Subset flag layer.
  #flaglayer.astype(int)
  # Find mask based on selected user flags.
  masked = (flaglayer & user_mask) != 0  
  print(np.max(masked))
  
  #### Load bands ####
  # SPM:
  rrs_555 = asarray(gd_group.variables['Rrs_555'])#*2.0e-6+0.05
  rrs_667 = asarray(gd_group.variables['Rrs_667'])#*2.0e-6+0.05
  rrs_748 = asarray(gd_group.variables['Rrs_748'])#*2.0e-6+0.05
  # chla = asarray(gd_group.variables['chlor_a'])
  # kd490 = asarray(gd_group.variables['Kd_490'])
  sst = asarray(gd_group.variables['sst'])
  # kdlee = asarray(gd_group.variables['Kd_488_lee'])
  par = asarray(gd_group.variables['par'])
  print(np.max(rrs_748))
  print(np.shape(latitude))
  print(np.shape(rrs_748))
  
  #### Rm masked pixels, <=0 at 555 and 667 nm and solz > 74 deg ####
  ind=np.where( (masked == 0) & (rrs_555 > 0.) & (rrs_667 > 0.) & (solz <= solz_max) )
  # Filter to ind values
  longikeep = longitude[ind]
  latikeep = latitude[ind]
  # chl = chla[ind] # Also make sure chl, kd and sst have same index as rrs and lon/lat
  #kd = kd490[ind]
  sst_data = sst[ind]
  #kdlee_data = kdlee[ind]
  par_data = par[ind]
  
  ##### SPM ####
  # SPM Ratio algorithm, Doxaran et al. Biogeosciences 2012, 2015: 
  rrs_ratio=rrs_748[ind]/rrs_555[ind]*100
  spm = 0.8386*rrs_ratio
  indgt2 = np.where( (rrs_ratio >= 87.) & (rrs_ratio <= 94.) )
  spm[indgt2]=70.+0.1416*rrs_ratio[indgt2]+2.9541*np.exp(0.4041*(rrs_ratio[indgt2]-87.)/1.9321)
  indgt3 = np.where(rrs_ratio > 94.)
  spm[indgt3]=3.922*rrs_ratio[indgt3]-285.4

  # SPM Han et al. Remote Sensing 2016;
  rhow_667 = rrs_667[ind] * np.pi
  spmL = 404.4 * rhow_667 / (1. - rhow_667 / 0.5)
  spmH = 1214.669 * rhow_667 / (1. - rhow_667 / 0.3394)
  WL = np.log10(0.04) - np.log10(rhow_667)
  WL[rhow_667 >= 0.04] = 0.
  WL[rhow_667 <= 0.03] = 1.
  WH = np.log10(rhow_667) - np.log10(0.03)
  WH[rhow_667 >= 0.04] = 1.
  WH[rhow_667 <= 0.03] = 0.
  spmhan = (WL * spmL + WH * spmH) / (WL + WH)
  
  # Keeping indices with valid SPM range
  indmes = np.where ( (spmhan > 0.00) & (spmhan < 1000.) )
    
  nb_good_pxl=longikeep[indmes].size
  print(longitude.size)
  # print(nb_good_pxl)
  
  if nb_good_pxl>0:
      print(nb_good_pxl,"valid pixels in file")
      #### Save data ####
      out_data=np.zeros((nb_good_pxl,7))-999.
      out_data[:,0]=longikeep[indmes]
      out_data[:,1]=latikeep[indmes]
      out_data[:,2]=spmhan[indmes] 
      out_data[:,3]=spm[indmes]
      # out_data[:,4]=kdlee_data[indmes]
      out_data[:,4]=sst_data[indmes]
      out_data[:,5]=par_data[indmes]
      
      print(np.min(spmhan[indmes]))
      print(np.max(spmhan[indmes]))
    
      f = open(ofile, 'w')
      np.savetxt(ofile, out_data, fmt='%15.10f')
      f.close()
  else:
      print("Zero valid pixels in file")

#--------------------------
#       Command Line
#--------------------------
if __name__=='__main__':
  main(*sys.argv[1:])
