from netCDF4 import Dataset
import numpy as np
import time, cPickle, sys, os
import dateutils
import pygrib

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    return (coslats*diff).mean()/meancoslats

date1 = sys.argv[1]
date2 = sys.argv[2]
exptname = sys.argv[3]
dates = dateutils.daterange(date1,date2,12)

fhour = 120
var = 'z'
vargrb = var
if var == 'z': vargrb = 'gh'
level = 500
res = 384  
nlons = 360; nlats = 181
latbound = 20 # boundary between tropics and extra-tropics
picklefile = 'C%s_grid.pickle' % res
analpath = '/scratch3/BMC/gsienkf/whitaker/ecanl'
datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % exptname
climopath =  '/scratch4/NCEPDEV/global/save/Fanglin.Yang/VRFY/vsdb/nwprod/fix/'

tri = cPickle.load(open(picklefile,'rb'))

olons_deg = (360./nlons)*np.arange(nlons)
olats_deg = -90 + (360./nlons)*np.arange(nlats)
olons = np.radians(olons_deg); olats = np.radians(olats_deg)
olons, olats = np.meshgrid(olons, olats)
latslist = olats_deg.tolist()
latnh = latslist.index(latbound)
latsh = latslist.index(-latbound)
coslats = np.cos(olats)
coslatssh = coslats[:latsh+1,:]
coslatsnh = coslats[latnh:,:]
coslatstr = coslats[latsh:latnh+1,:]

rmsnhall=[];rmsshall=[];rmstrall=[];rmsglall=[]
bias = None; ntime = None
for date in dates:
    datev = dateutils.dateshift(date,fhour)
    filea = os.path.join(analpath,'pgbanl.ecm.%s' % datev)
    grbs = pygrib.open(filea)
    grb = grbs.select(shortName=vargrb,level=level)[0]
    verif_data = grb.values[::-1,:]
    grbs.close()
    print verif_data.shape, verif_data.min(), verif_data.max()
    # read data from tiled  history files.
    cube_data = np.zeros((6,res,res),np.float32)
    for ntile in range(1,7,1):
        datafile = '%s/%s/longfcst/fv3_history.tile%s.nc'% (datapath,date,ntile)
        nc = Dataset(datafile)
        if ntime is None:
            times = nc['time'][:].tolist()
            ntime = times.index(fhour+6) # initial time is 6 hours before analysis time.
        cube_data[ntile-1,:,:] = nc['%s%s'%(var,level)][ntime,:,:]
        nc.close()
    cube_data = cube_data.reshape(6*res*res)
    # interpolate tiles to lat/lon grid
    latlon_data = tri.interp_linear(olons,olats,cube_data)
    print latlon_data.shape, latlon_data.min(), latlon_data.max()
    err = verif_data - latlon_data
    if bias is None:
        bias = err/len(dates)
    else:
        bias += err/len(dates)
    #import matplotlib.pyplot as plt
    #plt.figure()
    #clevs = np.arange(-100,101,10)
    #cs = plt.contourf(olons_deg,olats_deg,err,clevs,cmap=plt.cm.bwr,extend='both')
    #plt.title('error')
    #plt.colorbar()
    #plt.show()
    #raise SystemExit
    rmssh = np.sqrt(getmean(err[:latsh+1,:]**2,coslatssh))
    rmsnh = np.sqrt(getmean(err[latnh:,:]**2,coslatsnh))
    rmstr = np.sqrt(getmean(err[latsh:latnh+1,:]**2,coslatstr))
    rmsgl = np.sqrt(getmean(err**2,coslats))
    print '%s %6.2f %6.2f %6.2f %6.2f' %\
    (date,rmsnh,rmstr,rmssh,rmsgl)
    rmsshall.append(rmssh); rmsnhall.append(rmsnh)
    rmstrall.append(rmstr); rmsglall.append(rmsgl)
rmsnh = np.asarray(rmsnhall)
rmssh = np.asarray(rmsshall)
rmstr = np.asarray(rmstrall)
rmsgl = np.asarray(rmsglall)
print '%s-%s %6.2f %6.2f %6.2f %6.2f' %\
(date1,date2,rmsnh.mean(),rmstr.mean(),rmssh.mean(),rmsgl.mean())
#import matplotlib.pyplot as plt
#plt.figure()
#clevs = np.arange(-50,51,5)
#cs = plt.contourf(olons_deg,olats_deg,bias,clevs,cmap=plt.cm.bwr,extend='both')
#plt.title('bias')
#plt.colorbar()
#plt.show()
