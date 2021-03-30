import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys, os
from dateutils import daterange
from netCDF4 import Dataset
control = sys.argv[1]
expt = sys.argv[2]
date1 = sys.argv[3]
date2 = sys.argv[4]
dates = daterange(date1,date2,6)
datapathc = '/work/noaa/gsienkf/whitaker/%s' % control
datapathx = '/work/noaa/gsienkf/whitaker/%s' % expt 
lats = None
var = 'vgrd'
for date in dates:
    print(date)
    filenamec = os.path.join(os.path.join(datapathc,date),'sfg_%s_fhr06_enssprd' % date)
    nc = Dataset(filenamec)
    if lats is None:
       lats = nc['lat'][:]
       levs = nc['pfull'][:]
       nlats = len(lats); nlevs = len(levs)
       spreadc = np.zeros((nlevs,nlats),np.float32)
       spreadx = np.zeros((nlevs,nlats),np.float32)
    spreadc = spreadc  + (nc[var][:].squeeze()).mean(axis=-1)/len(dates)
    nc.close()
    filenamex = os.path.join(os.path.join(datapathx,date),'sfg2_%s_fhr08_enssprd' % date)
    nc = Dataset(filenamex)
    spreadx = spreadx  + (nc[var][:].squeeze()).mean(axis=-1)/len(dates)
    nc.close()
print(spreadx.min(), spreadx.max())
print(spreadc.min(), spreadc.max())
spread_diff = spreadx - spreadc
print(spread_diff.min(), spread_diff.max(), spread_diff.shape)
print(spreadx.mean(), spreadc.mean())
if var in ['ugrd','vgrd']:
   clevs = np.arange(-1.0,1.01,0.1)
   #clevs = np.arange(-0.5,0.51,0.05)
elif var == 'tmp':
   clevs = np.arange(-0.25,0.251,0.025)
lats1 = lats[:,0]
lats, levs = np.meshgrid(lats1, levs)
plt.contourf(lats, levs[::-1], spread_diff[::-1], clevs, cmap=plt.cm.bwr, extend='both')
plt.ylim(1000,0)
plt.colorbar()
plt.title('%s spread diff %s-%s' % (var,expt,control))
plt.savefig('spread_diff_%s.png' % expt)
plt.show()
