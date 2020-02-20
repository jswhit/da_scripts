from __future__ import print_function
from netCDF4 import Dataset
import numpy as np
import time, sys, os
try:
   import cPickle
except ImportError:
   import _pickle as cPickle

python3 = sys.version_info[0] > 2

# interpolate fv3 history files to lat/lon grid.
# assumes all variables are 3d with dimensions time, grid_yt, grid_xt

if len(sys.argv) < 5:
    print('incorrect number of arguments: python ncinterp.py datapath fileout RES refdate')
    raise SystemExit

nlons = 360; nlats = 181
zlib = True; lsd = None # lossy compression, lsd significant digits

datapath = sys.argv[1]
fileout = sys.argv[2]
res = int(sys.argv[3])
refdate = sys.argv[4]

# read in triangulation.
if python3:
   picklefile = 'C%s_grid.pickle.py3' % res
else:
   picklefile = 'C%s_grid.pickle' % res
tri = cPickle.load(open(picklefile,'rb'))

# define output grid.
olons_deg = (360./nlons)*np.arange(nlons)
olats_deg = -90 + (360./nlons)*np.arange(nlats)
olons = np.radians(olons_deg); olats = np.radians(olats_deg)
olons, olats = np.meshgrid(olons, olats)

# open all history files.
ncfiles = []
for ntile in range(1,7,1):
    datafile = '%s/fv3_historyp.tile%s.nc'% (datapath,ntile)
    ncfiles.append(Dataset(datafile))
# get times and variable names.
nc = ncfiles[0]
varnames = nc.variables.keys()
timesin = nc['time'][:]
plevs = nc['plev'][:]; nlevs = len(plevs)
# IAU/replay forecasts, shift time origin it is relative to middle of analysis window
if timesin[0] == 6: 
   timesin = timesin - 6
# only interp & save 3,6,9 and 12 hour forecasts, and then times that are multiples of 24 hours
times = []; itimes = []
for i,time in enumerate(timesin):
    if not time % 24 or time in [3,6,9,12]:
        times.append(time)
        itimes.append(i)
times = np.asarray(times); ntimes = len(times)

ncout = Dataset(fileout ,'w',format='NETCDF4_CLASSIC')
# define dimensions, coordinate vars in output file
latd = ncout.createDimension('latitude',nlats)
lats = ncout.createVariable('latitude',np.float32,'latitude')
lats.units = 'degrees north'
lats[:] =  olats_deg
lond = ncout.createDimension('longitude',nlons)
lons = ncout.createVariable('longitude',np.float32,'longitude')
lons.units = 'degrees east'
lons[:] =  olons_deg
timed = ncout.createDimension('time',ntimes)
t = ncout.createVariable('time',np.float32,'time')
t.units = 'hours since %s-%s-%s %s:00:00' % (refdate[0:4],refdate[4:6],refdate[6:8],refdate[8:10])
t[:] = times
levd = ncout.createDimension('plev',nlevs)
p = ncout.createVariable('plev',np.float32,'plev')
p.units = 'hPa'
p[:] = plevs

for varname in varnames:
    # skip coordinate variables.
    if varname in ['plev','grid_xt','grid_yt','time']: continue
    # define variable in output file.
    if nc[varname].ndim == 3:
        varout = ncout.createVariable(varname, np.float32, ('time','latitude','longitude'),zlib=zlib,least_significant_digit=lsd)
        print('processing ',varname)
        if varname.startswith('u') or varname.startswith('v'):
            varout.units = 'm/sec'
        if varname == 'tmp2m': varout.units = 'K'
        if varname == 'pwat': varout.units = 'mm'
        if varname.startswith('prate'): varout.units = 'mm/sec'
        if varname == 'pressfc': varout.units = 'Pa'
        if varname in ['slp','pmaskv2']: varout.units = 'hPa'
        # read cube data for this variable.
        cube_data = np.empty((ntimes,6,res,res),np.float32)
        for ntile in range(6):
            # assume all variables are 3d (time, grid_yt, grid_xt)
            nc = ncfiles[ntile]
            var = nc[varname]
            cube_data[:,ntile,:,:] = var[itimes]
        cube_data = cube_data.reshape(ntimes,6*res*res)
        latlon_data = np.empty((ntimes,nlats,nlons),np.float32)
        # interpolate tiles to lat/lon grid for each time for this variable.
        for ntime in range(ntimes):
            latlon_data[ntime] = tri.interp_linear(olons,olats,cube_data[ntime])
            #print(ntime, varout[ntime].min(), varout[ntime].max())
        varout[:] = latlon_data
    else:
        varout = ncout.createVariable(varname, np.float32, ('time','plev','latitude','longitude'),zlib=zlib,least_significant_digit=lsd)
        print('processing ',varname)
        if varname.startswith('u') or varname.startswith('v'):
            varout.units = 'm/sec'
        if varname == 'h_plev': varout.units = 'gpm'
        if varname == 't_plev': varout.units = 'K'
        if varname == 'q_plev': varout.units = 'kg/kg'
        # read cube data for this variable.
        cube_data = np.empty((ntimes,nlevs,6,res,res),np.float32)
        for ntile in range(6):
           # assume all variables are 3d (time, grid_yt, grid_xt)
            nc = ncfiles[ntile]
            var = nc[varname]
            cube_data[:,:,ntile,:,:] = var[itimes]
        cube_data = cube_data.reshape(ntimes,nlevs,6*res*res)
        latlon_data = np.empty((ntimes,nlevs,nlats,nlons),np.float32)
        # interpolate tiles to lat/lon grid for each time for this variable.
        for ntime in range(ntimes):
            for nlev in range(nlevs):
                    latlon_data[ntime,nlev] = tri.interp_linear(olons,olats,cube_data[ntime,nlev])
                    #print(ntime, nlev, varout[ntime,nlev].min(), varout[ntime,nlev].max())
        varout[:] = latlon_data

# close all files.
for nc in ncfiles:
    nc.close()
ncout.close()
