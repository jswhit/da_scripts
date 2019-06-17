import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys, os
import dateutils
from dateutils import daterange
from netCDF4 import Dataset
from spharm import Spharmt, getspecindx
from matplotlib.ticker import FormatStrFormatter,FuncFormatter,LogLocator

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
dates = dateutils.daterange(date1,date2,6)
var = 'tmpmidlayer'
#var = 'pressfc'
nlev = 25
alpha = 0.5

spec1 = None; spec2 = None; spec3 = None; spec4 = None
for date in dates:

    # get first guess for expt 1 (hybrid gain)
    datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt1
    print datapath
    print date
    filename = os.path.join(os.path.join(datapath,date),'sfg_%s_fhr06_ensmean.nc4' % date)
    nc = Dataset(filename)
    if spec1 is None:
        lons = nc['lon'][:]
        lats = nc['lat'][::-1]
        nlats = len(lats); nlons = len(lons)
        lons2, lats2 = np.meshgrid(lons, lats)
        re = 6.3712e6; ntrunc=nlats-1
        spec = Spharmt(nlons,nlats,rsphere=re,gridtype='regular',legfunc='computed')
        indxm, indxn = getspecindx(ntrunc)
        degree = indxn.astype(np.float)
    if var == 'pressfc':
        fg1 = nc[var][0,::-1,...]
    else:
        fg1 = nc[var][0,nlev,::-1,...]
    nc.close()

    # get first guess for expt 2 (hybrid cov/envar)
    datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt2
    print datapath
    print date
    filename = os.path.join(os.path.join(datapath,date),'sfg_%s_fhr06_ensmean.nc4' % date)
    nc = Dataset(filename)
    if var == 'pressfc':
        fg2 = nc[var][0,::-1,...]
    else:
        fg2 = nc[var][0,nlev,::-1,...]
    nc.close()
    
    # get 3dvar increment from hybrid gain expt (expt1)
    datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt1
    filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_control.nc4' % date)
    nc = Dataset(filename)
    if var == 'pressfc':
        varinc = nc[var][0,::-1,...] - fg1
    else:
        varinc = nc[var][0,nlev,::-1,...] - fg1
    nc.close()
    
    # get enkf increment from hybrid gain expt
    filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_ensmean.orig.nc4' % date)
    nc = Dataset(filename)
    if var == 'pressfc':
        enkfinc = nc[var][0,::-1,...] - fg1
    else:
        enkfinc = nc[var][0,nlev,::-1,...] - fg1
    nc.close()
    
    inc = enkfinc + alpha*varinc
    print inc.min(), inc.max(), inc.min(), inc.max()
    print 'global RMS',expt1,getrms(inc,np.cos(np.radians(lats2)))
    
    incspec = spec.grdtospec(inc)
    if spec1 is None:
        spec1 = getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    else:
        spec1 += getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    
    # get hybrid cov increment (expt2)
    datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt2
    print datapath
    filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_control.nc4' % date)
    nc = Dataset(filename)
    if var == 'pressfc':
        inc = nc[var][0,::-1,...] - fg2
    else:
        inc = nc[var][0,nlev,::-1,...] - fg2
    nc.close()
    print inc.min(), inc.max(), inc.min(), inc.max()
    print 'global RMS',expt2,getrms(inc,np.cos(np.radians(lats2)))
    
    incspec = spec.grdtospec(inc)
    if spec2 is None:
        spec2 = getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    else:
        spec2 += getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    
    # enkf increment expt1
    inc = enkfinc
    print inc.min(), inc.max(), inc.min(), inc.max()
    print 'global RMS EnKF',expt1,getrms(inc,np.cos(np.radians(lats2)))
    
    incspec = spec.grdtospec(inc)
    if spec3 is None:
        spec3 = getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    else:
        spec3 += getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    
    # 3dvar increment expt2
    inc = varinc
    print inc.min(), inc.max(), inc.min(), inc.max()
    print 'global RMS 3DVar',expt1,getrms(inc,np.cos(np.radians(lats2)))
    
    incspec = spec.grdtospec(inc)
    if spec4 is None:
        spec4 = getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)
    else:
        spec4 += getvarspectrum(incspec,indxm,indxn,ntrunc)/len(dates)

fout = open('spectrum_test.txt','w')
for n in xrange(ntrunc+1):
    fout.write('%s %g %g\n' % (n,spec1[n],spec2[n]))
fout.close()
print 'global RMS spectra',expt1,expt2,np.sqrt(spec1.sum()), np.sqrt(spec2.sum())
plt.semilogy(np.arange(ntrunc+1),spec1,color='b',linewidth=2,\
        label='Hybrid Gain Increment')
plt.semilogy(np.arange(ntrunc+1),spec2,color='r',linewidth=2,\
        label='Hybrid Cov Increment')
plt.semilogy(np.arange(ntrunc+1),spec3,color='k',linewidth=2,\
        label='EnKF Increment')
plt.semilogy(np.arange(ntrunc+1),spec4,'k:',linewidth=2,\
        label='3DVar Increment')
plt.legend(loc=0)
#plt.ylim(1.e-6,1.e-2)
#plt.xlim(0,ntrunc-1)
plt.ylim(1.e-5,1.e-2)
plt.xlim(0,180)
plt.xlabel('total wavenumber')
plt.ylabel('increment variance')
plt.title('Increment spectrum %s nlev=%s (%s-%s)' % (var,nlev,date1,date2))
plt.savefig('spectrum_test.png')
plt.show()
