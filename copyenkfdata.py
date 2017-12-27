from netCDF4 import Dataset
import sys

# copy enkf data to hybrid diag file.

file_enkf = sys.argv[1]
file_hybrid = sys.argv[2]
id = sys.argv[3]

nc_enkf = Dataset(file_enkf)
nc_hybrid = Dataset(file_hybrid,'a')

nobs_enkf = len(nc_enkf.dimensions['nobs'])
nobs_hybrid = len(nc_hybrid.dimensions['nobs'])
if nobs_enkf != nobs_hybrid:
    raise ValueError('nobs not the same in the two files')

vars_to_copy = [var for var in nc_enkf.variables.keys() if 'EnKF' in var and id in var]

for varname in vars_to_copy:
    print 'appending %s...' % varname
    var = nc_enkf[varname]
    varnew = nc_hybrid.createVariable(varname, var.dtype, var.dimensions, zlib=True)
    varnew[:] = var[:]

nc_enkf.close()
nc_hybrid.close()
