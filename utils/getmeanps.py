#import matplotlib
#matplotlib.use('Agg')
#import matplotlib.pyplot as plt
import numpy as np
import sys, os
import dateutils
from dateutils import daterange
from netCDF4 import Dataset

def getmean(field,coslats):
    meancoslats = coslats.mean()
    return (coslats*field).mean()/meancoslats

expt = sys.argv[1]
date1 = sys.argv[2]
date2 = sys.argv[3]
dates = dateutils.daterange(date1,date2,6)
coslats = None

for date in dates:
    datapath = '/scratch2/BMC/gsienkf/whitaker/%s/%s/sfg_%s_fhr03_ensmean' % (expt,date,date)
    nc = Dataset(datapath)
    if coslats is None:
        lons2d = nc['lon'][:]
        lats2d = nc['lat'][:]
        lons1d = lons2d[0,:]
        lats1d = lats2d[:,0]
        nlats = len(lats1d); nlons = len(lons1d)
        coslats = np.cos(np.radians(lats2d))
    meanps = getmean(nc['pressfc'][0,...],coslats)
    print(date, meanps)
    nc.close()
