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

fhour = 120
var = 'z'
level = 500 

vargrb = var
if var == 'z': 
    vargrb = 'gh'
    varnc = 'h_plev'

latbound = 20 # boundary between tropics and extra-tropics 
analpath = '/scratch2/BMC/gsienkf/whitaker/ecanl_1d'
datapath1 = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/%s' % expt1
datapath2 = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/%s' % expt2
climopath =  '/scratch1/NCEPDEV/global/glopara/fix/fix_verif/climo_files/'

dates = dateutils.daterange(date1,date2,24)
rmsnhall1=[];rmsshall1=[];rmstrall1=[];rmsglall1=[]
acnhall1=[];acshall1=[];actrall1=[];acglall1=[]
rmsnhall2=[];rmsshall2=[];rmstrall2=[];rmsglall2=[]
acnhall2=[];acshall2=[];actrall2=[];acglall2=[]
lats1d = None
for date in dates:
    datev = dateutils.dateshift(date,fhour)
    # read analysis
    analfile = os.path.join(analpath,'z_plevs_%s.grb' % datev)
    grbs = pygrib.open(analfile)
    grb = grbs.select(shortName='z',level=level)[0]
    verif_data = grb.values[::-1,:]/9.80665 # reverse lats (so they are S to N)
    #print(verif_data.min(), verif_data.max())
    #lats2d, lons2d = grb.latlons() 
    #lats1d = lats2d[:,0]; lons1d = lons2d[0,:]
    #print(lats1d)
    #raise SystemExit
    # read climo
    climofile = os.path.join(climopath,'cmean_1d.1959%s'%datev[4:8])
    #print(climofile)
    grbsclimo = pygrib.open(climofile)
    yyyy,mm,dd,hh = dateutils.splitdate(datev)
    grbclimo = grbsclimo.select(shortName='gh',level=level,dataTime=100*hh)[0]
    climo_data = grbclimo.values[::-1,:]
    #print(climo_data.min(), climo_data.max())
    grbsclimo.close()
    yyyy,mm,dd,hh = dateutils.splitdate(date)
    fcstfile = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/pgb1d/%s/gfs.%04i%02i%02i/%02i/atmos/gfs.t%02iz.pgrb2.1p00.f%03i' % (expt1,yyyy,mm,dd,hh,hh,fhour)
    #print(fcstfile)
    grbsfcst1 = pygrib.open(fcstfile)
    grbfcst1 = grbsfcst1.select(shortName='gh',level=level)[0]
    fcst_data1 = grbfcst1.values[::-1,:]
    #print(fcst_data1.min(), fcst_data1.max())
    grbsfcst1.close()
    fcstfile = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/pgb1d/%s/gfs.%04i%02i%02i/%02i/atmos/gfs.t%02iz.pgrb2.1p00.f%03i' % (expt2,yyyy,mm,dd,hh,hh,fhour)
    #print(fcstfile)
    grbsfcst2 = pygrib.open(fcstfile)
    grbfcst2 = grbsfcst2.select(shortName='gh',level=level)[0]
    fcst_data2 = grbfcst2.values[::-1,:]
    #print(fcst_data2.min(), fcst_data2.max())
    if lats1d is None:
        lats2d, lons2d = grbfcst2.latlons() 
        lats1d = lats2d[::-1,0]; lons1d = lons2d[0,:]
        latslist = lats1d.tolist()
        latnh = latslist.index(latbound)
        latsh = latslist.index(-latbound)
        #print lats1d[:latsh]
        #print lats1d[latsh:latnh+1]
        #print lats1d[latnh+1:]
        #raise SystemExit
        coslats = np.cos(np.radians(lats2d[::-1,:]))
        coslatssh = coslats[:latsh,:]
        coslatsnh = coslats[latnh+1:,:]
        coslatstr = coslats[latsh:latnh+1,:]
        nlons = len(lons1d); nlats = len(lats1d)
    grbsfcst2.close()

    fcsterr1 = fcst_data1 - verif_data
    fcsterr2 = fcst_data2 - verif_data
    fanom1 = fcst_data1 - climo_data
    fanom2 = fcst_data2 - climo_data
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
