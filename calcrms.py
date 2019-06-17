from netCDF4 import Dataset
import numpy as np
import sys, os
import dateutils
import pygrib

# compute rms and anomaly correlation using interpolated cubed-sphere pressure-level history files.

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    return (coslats*diff).mean()/meancoslats

expt1 = sys.argv[1]
expt2 = sys.argv[2]
date1 = sys.argv[3]
date2 = sys.argv[4]

fhour = 6
var = 'z'
level = 500 

vargrb = var
varnc = '%s_plev' % var
if var == 'z': 
    vargrb = 'gh'
    varnc = 'h_plev'

latbound = 20 # boundary between tropics and extra-tropics 
analpath = '/scratch3/BMC/gsienkf/whitaker/ecanl'
datapath1 = '/scratch3/BMC/gsienkf/whitaker/%s' % expt1
datapath2 = '/scratch3/BMC/gsienkf/whitaker/%s' % expt2
climopath =  '/scratch4/NCEPDEV/global/save/Fanglin.Yang/VRFY/vsdb/nwprod/fix/'

if fhour > 9:
    dates = dateutils.daterange(date1,date2,24)
else:
    dates = dateutils.daterange(date1,date2,6)
#dates.remove('2016011300')
#dates.remove('2016010912')
ntime = None; fcsterrspect1 = None; fcsterrspect2 = None
rmsnhall1=[];rmsshall1=[];rmstrall1=[];rmsglall1=[]
acnhall1=[];acshall1=[];actrall1=[];acglall1=[]
rmsnhall2=[];rmsshall2=[];rmstrall2=[];rmsglall2=[]
acnhall2=[];acshall2=[];actrall2=[];acglall2=[]
for date in dates:
    datev = dateutils.dateshift(date,fhour)
    # read analysis
    analfile = os.path.join(analpath,'pgbanl.ecm.%s' % datev)
    grbs = pygrib.open(analfile)
    grb = grbs.select(shortName=vargrb,level=level)[0]
    verif_data = grb.values[::-1,:]
    grbs.close()
    # read climo
    grbsclimo = pygrib.open(os.path.join(climopath,'cmean_1d.1959%s'%datev[4:8]))
    yyyy,mm,dd,hh = dateutils.splitdate(datev)
    grbclimo = grbsclimo.select(shortName=vargrb,level=level,dataTime=100*hh)[0]
    climo_data = grbclimo.values[::-1,:]
    grbsclimo.close()
    if fhour > 9:
        fcstfile = '%s/%s/fv3longcontrol2_historyp_%s_latlon.nc'% (datapath1,date,date)
    else:
        fcstfile = '%s/%s/fv3control2_historyp_%s_latlon.nc'% (datapath1,date,date)
    nc = Dataset(fcstfile)
    if ntime is None:
        lons = nc['longitude'][:]; lats = nc['latitude'][:]
        latslist = lats.tolist()
        latnh = latslist.index(latbound)
        latsh = latslist.index(-latbound)
        #print lats[:latsh]
        #print lats[latsh:latnh+1]
        #print lats[latnh+1:]
        #raise SystemExit
        lons2, lats2 = np.meshgrid(lons, lats)
        coslats = np.cos(np.radians(lats2))
        coslatssh = coslats[:latsh,:]
        coslatsnh = coslats[latnh+1:,:]
        coslatstr = coslats[latsh:latnh+1,:]
        nlons = len(lons); nlats = len(lats)
    times = nc['time'][:].tolist()
    levels = nc['plev'][:].tolist()
    ntime = times.index(fhour)
    nlev = levels.index(level)
    if int(nc['time'][ntime]) != fhour:
       raise ValueError('incorrect forecast time')
    fcst_data1 = nc[varnc][ntime,nlev,...]
    pmask1 = nc['pmaskv2'][ntime,...]
    #pmask1 = nc['pressfc'][ntime,...]/100.
    nc.close()
    if fhour > 9:
        fcstfile = '%s/%s/fv3longcontrol2_historyp_%s_latlon.nc'% (datapath2,date,date)
    else:
        fcstfile = '%s/%s/fv3control2_historyp_%s_latlon.nc'% (datapath2,date,date)
    nc = Dataset(fcstfile)
    times = nc['time'][:].tolist()
    levels = nc['plev'][:].tolist()
    ntime = times.index(fhour)
    nlev = levels.index(level)
    if int(nc['time'][ntime]) != fhour:
       raise ValueError('incorrect forecast time')
    fcst_data2 = nc[varnc][ntime,nlev,...]
    pmask2 = nc['pmaskv2'][ntime,...]
    #pmask2 = nc['pressfc'][ntime,...]/100.
    nc.close()
    #print date,verif_data.shape,verif_data.min(),verif_data.max(),\
    #           fcst_data1.shape,fcst_data1.min(),fcst_data1.max(),\
    #           fcst_data2.shape,fcst_data2.min(),fcst_data2.max()
    # mask all points that are underground in either forecast
    fcsterr1 = np.ma.array(fcst_data1 - verif_data,mask=pmask1<level)
    fcsterr2 = np.ma.array(fcst_data2 - verif_data,mask=pmask2<level)
    fanom1 = np.ma.array(fcst_data1 - climo_data,mask=pmask1<level)
    fanom2 = np.ma.array(fcst_data2 - climo_data,mask=pmask2<level)
    vanom = verif_data - climo_data

    rmssh1 = np.sqrt(getmean(fcsterr1[:latsh,:]**2,coslatssh))
    rmsnh1 = np.sqrt(getmean(fcsterr1[latnh+1:,:]**2,coslatsnh))
    rmstr1 = np.sqrt(getmean(fcsterr1[latsh:latnh+1,:]**2,coslatstr))
    rmsgl1 = np.sqrt(getmean(fcsterr1**2,coslats))
    rmsshall1.append(rmssh1); rmsnhall1.append(rmsnh1)
    rmstrall1.append(rmstr1); rmsglall1.append(rmsgl1)
    rmssh2 = np.sqrt(getmean(fcsterr2[:latsh,:]**2,coslatssh))
    rmsnh2 = np.sqrt(getmean(fcsterr2[latnh+1:,:]**2,coslatsnh))
    rmstr2 = np.sqrt(getmean(fcsterr2[latsh:latnh+1,:]**2,coslatstr))
    rmsgl2 = np.sqrt(getmean(fcsterr2**2,coslats))
    rmsshall2.append(rmssh2); rmsnhall2.append(rmsnh2)
    rmstrall2.append(rmstr2); rmsglall2.append(rmsgl2)

    cov1 = fanom1*vanom; fvar1 = fanom1**2; vvar = vanom**2
    acsh1 = getmean(cov1[:latsh:],coslatssh)/(np.sqrt(getmean(fvar1[:latsh:],coslatssh))*np.sqrt(getmean(vvar[:latsh:],coslatssh)))
    acnh1 = getmean(cov1[latnh+1:,:],coslatsnh)/(np.sqrt(getmean(fvar1[latnh+1:,:],coslatsnh))*np.sqrt(getmean(vvar[latnh+1:,:],coslatsnh)))
    actr1 = getmean(cov1[latsh:latnh+1,:],coslatstr)/(np.sqrt(getmean(fvar1[latsh:latnh+1,:],coslatstr))*np.sqrt(getmean(vvar[latsh:latnh+1,:],coslatstr)))
    acgl1 = getmean(cov1,coslats)/(np.sqrt(getmean(fvar1,coslats))*np.sqrt(getmean(vvar,coslats)))
    acshall1.append(acsh1); acnhall1.append(acnh1)
    actrall1.append(actr1); acglall1.append(acgl1)
    cov2 = fanom2*vanom; fvar2 = fanom2**2
    acsh2 = getmean(cov2[:latsh:],coslatssh)/(np.sqrt(getmean(fvar2[:latsh:],coslatssh))*np.sqrt(getmean(vvar[:latsh:],coslatssh)))
    acnh2 = getmean(cov2[latnh+1:,:],coslatsnh)/(np.sqrt(getmean(fvar2[latnh+1:,:],coslatsnh))*np.sqrt(getmean(vvar[latnh+1:,:],coslatsnh)))
    actr2 = getmean(cov2[latsh:latnh+1,:],coslatstr)/(np.sqrt(getmean(fvar2[latsh:latnh+1,:],coslatstr))*np.sqrt(getmean(vvar[latsh:latnh+1,:],coslatstr)))
    acgl2 = getmean(cov2,coslats)/(np.sqrt(getmean(fvar2,coslats))*np.sqrt(getmean(vvar,coslats)))
    acshall2.append(acsh2); acnhall2.append(acnh2)
    actrall2.append(actr2); acglall2.append(acgl2)

    print '%s %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f' %\
    (date,rmsnh1,rmsnh2,rmstr1,rmstr2,rmssh1,rmssh2,rmsgl1,rmsgl2,acnh1,acnh2,actr1,actr2,acsh1,acsh2,acgl1,acgl2)

rmsnh1 = np.asarray(rmsnhall1).mean(); acnh1 = np.asarray(acnhall1).mean()
rmssh1 = np.asarray(rmsshall1).mean(); acsh1 = np.asarray(acshall1).mean()
rmstr1 = np.asarray(rmstrall1).mean(); actr1 = np.asarray(actrall1).mean()
rmsgl1 = np.asarray(rmsglall1).mean(); acgl1 = np.asarray(acglall1).mean()
rmsnh2 = np.asarray(rmsnhall2).mean(); acnh2 = np.asarray(acnhall2).mean()
rmssh2 = np.asarray(rmsshall2).mean(); acsh2 = np.asarray(acshall2).mean()
rmstr2 = np.asarray(rmstrall2).mean(); actr2 = np.asarray(actrall2).mean()
rmsgl2 = np.asarray(rmsglall2).mean(); acgl2 = np.asarray(acglall2).mean()
print '#%s-%s %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f' %\
(date1,date2,rmsnh1,rmsnh2,rmstr1,rmstr2,rmssh1,rmssh2,rmsgl1,rmsgl2,acnh1,acnh2,actr1,actr2,acsh1,acsh2,acgl1,acgl2)
