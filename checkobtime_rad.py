from netCDF4 import Dataset
import numpy as np
import sys
diagfile = sys.argv[1]
nc = Dataset(diagfile)
used = nc['use_flag'][:]
oberrinv = nc['Inverse_Observation_Error'][:]
time = nc['Obs_Time'][:]
nobs = len(time)
ncount = 0
print(time.min(),time.max())
for nob in range(nobs):
    if time[nob] < -0.5 and used[nob] == 1 and oberrinv[nob] > 1.e-5:
        print(time[nob],  oberrinv[nob])
        ncount += 1
print(ncount)
