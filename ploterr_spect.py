import matplotlib
#matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys, os
import dateutils, pygrib
from netCDF4 import Dataset
from spharm import Spharmt, getspecindx
from matplotlib.ticker import FormatStrFormatter,FuncFormatter,LogLocator
from matplotlib import rcParams

rcParams['legend.fontsize']=12

def getrms(diff,coslats):
    meancoslats = coslats.mean()
    return np.sqrt((coslats*diff**2).mean()/meancoslats)

def getvarspectrum(dataspec,indxm,indxn,ntrunc):
    varspect = np.zeros(ntrunc+1,np.float)
    nlm = (ntrunc+1)*(ntrunc+2)/2
    for n in range(nlm):
        if indxm[n] == 0:
            varspect[indxn[n]] += (0.5*dataspec[n]*np.conj(dataspec[n])).real
        else:
            varspect[indxn[n]] += (dataspec[n]*np.conj(dataspec[n])).real
    return varspect


expt1 = sys.argv[1]
expt2 = sys.argv[2]
date1 = sys.argv[3]
date2 = sys.argv[4]

fhour = 120
var = 't'
level = 500
vargrb = var
varnc = '%s_plev' % var
if var == 'z': 
    vargrb = 'gh'
    varnc = 'h_plev'

datapath1 = '/scratch3/BMC/gsienkf/whitaker/%s' % expt1
datapath2 = '/scratch3/BMC/gsienkf/whitaker/%s' % expt2
analpath = '/scratch3/BMC/gsienkf/whitaker/ecanl'

if fhour > 9:
    dates = dateutils.daterange(date1,date2,24)
else:
    dates = dateutils.daterange(date1,date2,6)
ntime = None; fcsterrspect1 = None; fcsterrspect2 = None
for date in dates:
    datev = dateutils.dateshift(date,fhour)
    # read analysis
    analfile = os.path.join(analpath,'pgbanl.ecm.%s' % datev)
    grbs = pygrib.open(analfile)
    grb = grbs.select(shortName=vargrb,level=level)[0]
    verif_data = grb.values[::-1,:]
    grbs.close()
    if fhour > 9:
        fcstfile = '%s/%s/fv3longcontrol2_historyp_%s_latlon.nc'% (datapath1,date,date)
    else:
        fcstfile = '%s/%s/fv3control2_historyp_%s_latlon.nc'% (datapath1,date,date)
    nc = Dataset(fcstfile)
    if ntime is None:
        times = nc['time'][:].tolist()
        levels = nc['plev'][:].tolist()
        ntime = times.index(fhour)
        nlev = levels.index(level)
        lons = nc['longitude'][:]; lats = nc['latitude'][:]
        nlons = len(lons); nlats = len(lats)
        re = 6.3712e6; ntrunc=nlats-1
        spec = Spharmt(nlons,nlats,rsphere=re,gridtype='regular',legfunc='computed')
        indxm, indxn = getspecindx(ntrunc)
        degree = indxn.astype(np.float)
    if int(nc['time'][ntime]) != fhour:
       raise ValueError('incorrect forecast time')
    fcst_data1 = nc[varnc][ntime,nlev,...]
    nc.close()
    if fhour > 9:
        fcstfile = '%s/%s/fv3longcontrol2_historyp_%s_latlon.nc'% (datapath2,date,date)
    else:
        fcstfile = '%s/%s/fv3control2_historyp_%s_latlon.nc'% (datapath2,date,date)
    nc = Dataset(fcstfile)
    if int(nc['time'][ntime]) != fhour:
       raise ValueError('incorrect forecast time')
    fcst_data2 = nc[varnc][ntime,nlev,...]
    nc.close()
    #print date,verif_data.shape,verif_data.min(),verif_data.max(),\
    #           fcst_data1.shape,fcst_data1.min(),fcst_data1.max(),\
    #           fcst_data2.shape,fcst_data2.min(),fcst_data2.max()
    fcsterr = fcst_data1 - verif_data
    fcsterrspec = spec.grdtospec(fcsterr)
    varspec = getvarspectrum(fcsterrspec,indxm,indxn,ntrunc)
    rms1 = varspec.sum()
    if fcsterrspect1 is None:
        fcsterrspect1 = varspec/len(dates)
    else:
        fcsterrspect1 += varspec/len(dates)
    fcsterr = fcst_data2 - verif_data
    fcsterrspec = spec.grdtospec(fcsterr)
    varspec = getvarspectrum(fcsterrspec,indxm,indxn,ntrunc)
    rms2 = varspec.sum()
    if fcsterrspect2 is None:
        fcsterrspect2 = varspec/len(dates)
    else:
        fcsterrspect2 += varspec/len(dates)
    print date,np.sqrt(rms1),np.sqrt(rms2)

mean1 = np.sqrt(fcsterrspect1.sum())
mean2 = np.sqrt(fcsterrspect2.sum())
print 'global RMS spectra',expt1,expt2,mean1,mean2
plt.semilogy(np.arange(ntrunc+1),fcsterrspect1,color='b',linewidth=2,\
        label='%s Global RMS %4.2f' % (expt1,mean1))
plt.semilogy(np.arange(ntrunc+1),fcsterrspect2,color='r',linewidth=2,\
        label='%s Global RMS %4.2f' % (expt2,mean2))
plt.legend(loc=0)
#if var == 'z':
#    plt.ylim(1.e-3,10.)
#elif var == 't':
#    plt.ylim(6.e-4,1.e-2)
plt.xlim(0,ntrunc-1)
plt.xlabel('total wavenumber')
plt.ylabel('error variance (fcst vs EC analysis)')
plt.title('6-h forecast error spectrum %s %s (%s-%s)' % (var,level,date1,date2))
plt.savefig('spectrum_test.png')
plt.show()
