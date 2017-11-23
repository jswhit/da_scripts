from netCDF4 import Dataset
import numpy as np
import time, cPickle, sys, os
import dateutils
import pygrib

# compute rms error and anomaly correlation on 1 degree grid
# using native cubed-sphere history files.

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    return (coslats*diff).mean()/meancoslats

date1 = sys.argv[1]
date2 = sys.argv[2]
exptname = sys.argv[3]
dates = dateutils.daterange(date1,date2,12)

fhour = int(sys.argv[4])
var = sys.argv[5]
level = int(sys.argv[6])
#fhour = 120
#var = 'z'
#level = 500
vargrb = var
if var == 'z': vargrb = 'gh'
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
acnhall=[];acshall=[];actrall=[];acglall=[]
bias = None; ntime = None
for date in dates:
    datev = dateutils.dateshift(date,fhour)
    # read analysis
    filea = os.path.join(analpath,'pgbanl.ecm.%s' % datev)
    grbs = pygrib.open(filea)
    grb = grbs.select(shortName=vargrb,level=level)[0]
    verif_data = grb.values[::-1,:]
    grbs.close()
    #print verif_data.shape, verif_data.min(), verif_data.max()
    # read climo
    grbsclimo = pygrib.open(os.path.join(climopath,'cmean_1d.1959%s'%datev[4:8]))
    yyyy,mm,dd,hh = dateutils.splitdate(datev)
    grbclimo = grbsclimo.select(shortName=vargrb,level=level,dataTime=100*hh)[0]
    climo_data = grbclimo.values[::-1,:]
    grbsclimo.close()
    #print climo_data.shape, climo_data.min(), climo_data.max()
    # read forecast data from tiled history files.
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
    #print latlon_data.shape, latlon_data.min(), latlon_data.max()
    err = verif_data - latlon_data
    fanom = latlon_data - climo_data
    vanom = verif_data - climo_data
    if bias is None:
        bias = err/len(dates)
    else:
        bias += err/len(dates)
    #import matplotlib.pyplot as plt
    #plt.figure()
    #clevs = np.arange(-400,401,20)
    #cs = plt.contourf(olons_deg,olats_deg,fanom,clevs,cmap=plt.cm.bwr,extend='both')
    #plt.title('forecast anomaly')
    #plt.colorbar()
    #plt.figure()
    #cs = plt.contourf(olons_deg,olats_deg,vanom,clevs,cmap=plt.cm.bwr,extend='both')
    #plt.title('analyzed anomaly')
    #plt.colorbar()
    #plt.show()
    #raise SystemExit
    rmssh = np.sqrt(getmean(err[:latsh+1,:]**2,coslatssh))
    rmsnh = np.sqrt(getmean(err[latnh:,:]**2,coslatsnh))
    rmstr = np.sqrt(getmean(err[latsh:latnh+1,:]**2,coslatstr))
    rmsgl = np.sqrt(getmean(err**2,coslats))
    rmsshall.append(rmssh); rmsnhall.append(rmsnh)
    rmstrall.append(rmstr); rmsglall.append(rmsgl)
    cov = fanom*vanom; fvar = fanom**2; vvar = vanom**2
    acsh = getmean(cov[:latsh+1:],coslatssh)/(np.sqrt(getmean(fvar[:latsh+1:],coslatssh))*np.sqrt(getmean(vvar[:latsh+1:],coslatssh)))
    acnh = getmean(cov[latnh:,:],coslatsnh)/(np.sqrt(getmean(fvar[latnh:,:],coslatsnh))*np.sqrt(getmean(vvar[latnh:,:],coslatsnh)))
    actr = getmean(cov[latsh:latnh+1,:],coslatstr)/(np.sqrt(getmean(fvar[latsh:latnh+1,:],coslatstr))*np.sqrt(getmean(vvar[latsh:latnh+1,:],coslatstr)))
    acgl = getmean(cov,coslats)/(np.sqrt(getmean(fvar,coslats))*np.sqrt(getmean(vvar,coslats)))
    acshall.append(acsh); acnhall.append(acnh)
    actrall.append(actr); acglall.append(acgl)
    print '%s %6.2f %6.2f %6.2f %6.2f %7.3f %7.3f %7.3f %7.3f' %\
    (date,rmsnh,rmstr,rmssh,rmsgl,acnh,actr,acsh,acgl)
rmsnh = np.asarray(rmsnhall); acnh = np.asarray(acnhall)
rmssh = np.asarray(rmsshall); acsh = np.asarray(acshall)
rmstr = np.asarray(rmstrall); actr = np.asarray(actrall)
rmsgl = np.asarray(rmsglall); acgl = np.asarray(acglall)
print '%s-%s %6.2f %6.2f %6.2f %6.2f %7.3f %7.3f %7.3f %7.3f' %\
(date1,date2,rmsnh.mean(),rmstr.mean(),rmssh.mean(),rmsgl.mean(),\
 acnh.mean(),actr.mean(),acsh.mean(),acgl.mean())
#import matplotlib.pyplot as plt
#plt.figure()
#clevs = np.arange(-50,51,5)
#cs = plt.contourf(olons_deg,olats_deg,bias,clevs,cmap=plt.cm.bwr,extend='both')
#plt.title('bias')
#plt.colorbar()
#plt.show()
