import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys, os
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
date = sys.argv[3]

datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt1
print datapath
var = 'tmpmidlayer'
#var = 'pressfc'
nlev = 25
print date
filename = os.path.join(os.path.join(datapath,date),'sfg_%s_fhr06_ensmean.nc4' % date)
nc = Dataset(filename)
lons = nc['lon'][:]
lats = nc['lat'][::-1]
nlats = len(lats); nlons = len(lons)
lons2, lats2 = np.meshgrid(lons, lats)
if var == 'pressfc':
    fg = nc[var][0,::-1,...]
else:
    fg = nc[var][0,nlev,::-1,...]
nc.close()

filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_control.nc4' % date)
nc = Dataset(filename)
if var == 'pressfc':
    varinc = nc[var][0,::-1,...] - fg
else:
    varinc = nc[var][0,nlev,::-1,...] - fg
nc.close()

filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_ensmean.orig.nc4' % date)
nc = Dataset(filename)
if var == 'pressfc':
    enkfinc = nc[var][0,::-1,...] - fg
else:
    enkfinc = nc[var][0,nlev,::-1,...] - fg
nc.close()

inc = 1.00*enkfinc + 0.5*varinc
print inc.min(), inc.max(), inc.min(), inc.max()
print 'global RMS',expt1,getrms(inc,np.cos(np.radians(lats2)))

re = 6.3712e6; ntrunc=nlats-1
spec = Spharmt(nlons,nlats,rsphere=re,gridtype='regular',legfunc='computed')
incspec = spec.grdtospec(inc)
indxm, indxn = getspecindx(ntrunc)
degree = indxn.astype(np.float)

spec1 = getvarspectrum(incspec,indxm,indxn,ntrunc)

datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt2
print datapath
filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_control.nc4' % date)
nc = Dataset(filename)
if var == 'pressfc':
    inc = nc[var][0,::-1,...] - fg
else:
    inc = nc[var][0,nlev,::-1,...] - fg
nc.close()
print inc.min(), inc.max(), inc.min(), inc.max()
print 'global RMS',expt2,getrms(inc,np.cos(np.radians(lats2)))

incspec = spec.grdtospec(inc)
spec2 = getvarspectrum(incspec,indxm,indxn,ntrunc)

fout = open('spectrum_test.txt','w')
for n in xrange(ntrunc+1):
    fout.write('%s %g %g\n' % (n,spec1[n],spec2[n]))
fout.close()
print 'global RMS spectra',expt1,expt2,np.sqrt(spec1.sum()), np.sqrt(spec2.sum())
plt.semilogy(np.arange(ntrunc+1),spec1,color='b',linewidth=2,\
        label='Hybrid Gain Increment')
plt.semilogy(np.arange(ntrunc+1),spec2,color='r',linewidth=2,\
        label='Hybrid Cov Increment')
plt.legend(loc=0)
plt.ylim(1.e-6,1.e-2)
plt.xlim(0,ntrunc-1)
plt.savefig('spectrum_test.png')
plt.show()
