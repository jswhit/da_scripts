from netCDF4 import Dataset
import numpy as np
import sys
diagfile = sys.argv[1]
nc = Dataset(diagfile)
code = nc['Observation_Type'][:]
used = nc['Analysis_Use_Flag'][:]
oberrinv = nc['Errinv_Final'][:]
press = nc['Pressure'][:]
time = nc['Time'][:]
nobs = len(time)
ncount = 0
for nob in range(nobs):
    if time[nob] < -0.5 and used[nob] == 1 and oberrinv[nob] > 1.e-5:
        print(time[nob], code[nob], oberrinv[nob])
        ncount += 1
print(nobs, ncount)
raise SystemExit
imin = np.argmin(time); imax = np.argmax(time)
print(time.min(), code[imin], used[imin], oberrinv[imin])
print(time.max(), code[imax], used[imax], oberrinv[imax])
nc.close()
