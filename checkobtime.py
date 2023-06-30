from netCDF4 import Dataset
import sys
import numpy as np
diagfile = sys.argv[1]
nc = Dataset(diagfile)
try:
    time = nc['Time'][:]
except:
    time = nc['Obs_Time'][:]
used = nc['Analysis_Use_Flag'][:]
indx_used = used == 1
print(time[indx_used].min(), time[indx_used].max())
#print(time.min(), time.max())
