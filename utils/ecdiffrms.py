"""plot profiles of rms/bias relative to IFS analyses"""
import matplotlib
matplotlib.use('Agg')
from netCDF4 import Dataset
import numpy as np
import matplotlib.pyplot as plt
import os,sys,dateutils

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    mean = np.empty(diff.shape[0],diff.dtype)
    for k in range(diff.shape[0]):
        mean[k] = (coslats*diff[k]).mean()/meancoslats
    return mean[::-1]

date1 = sys.argv[1]
date2 = sys.argv[2]
expt1 = sys.argv[3]
expt2 = sys.argv[4]
region = sys.argv[5] # "NH", "TR" or "GL"

latbound = 20.
ifsanldir = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/C192ifsanalL64'
expbasedir = '/scratch2/BMC/gsienkf/whitaker'

dates = dateutils.daterange(date1,date2,6)
coslats = None
for date in dates:
    datev = dateutils.dateshift(date,12)
    ifsanl = os.path.join(ifsanldir,'C192_ifsanl_%s.nc'%datev)
    exptdir1 = os.path.join(expbasedir+'/'+expt1,datev)
    exptdir2 = os.path.join(expbasedir+'/'+expt2,datev)
    ufsfcst1 = os.path.join(exptdir1,'sfg2_%s_fhr12_ensmean'%datev)
    ufsfcst2 = os.path.join(exptdir2,'sfg2_%s_fhr12_ensmean'%datev)
    ncifs = Dataset(ifsanl)
    ncufs1 = Dataset(ufsfcst1)
    ncufs2 = Dataset(ufsfcst2)
    if coslats is None:
        lats = ncufs1['lat'][:]
        coslats = np.cos(np.radians(lats))
        if region == "GL":
            mask = np.zeros(coslats.shape,dtype=np.bool_)
        elif region == "TR":
            mask = np.logical_or(lats>=latbound, lats<=-latbound)
        elif region == "NH":
            mask = lats>latbound
        elif region == "SH":
            mask = lats<-latbound
        else:
            raise ValueError('region must be NH,SH or TR')
        coslats = np.ma.masked_array(coslats, mask)
        ak = ncufs1.ak; bk = ncufs1.bk # hybrid vertical coordinates
        plevs = 0.01*(ak[::-1] + bk[::-1]*1.e5) # hPa
        plevs_mid = 0.5*(plevs[1:]+plevs[:-1]) # mid-levels
        nlevs = len(plevs_mid)
        tmperrsq1=np.zeros(nlevs); tmperrsq2 = np.zeros(nlevs)
        tmpbias1=np.zeros(nlevs); tmpbias2 = np.zeros(nlevs)
        qerrsq1=np.zeros(nlevs); qerrsq2 = np.zeros(nlevs)
        qbias1=np.zeros(nlevs); qbias2 = np.zeros(nlevs)
        winderrsq1=np.zeros(nlevs); winderrsq2 = np.zeros(nlevs)
           
    tmpdiff1 = ncufs1['tmp'][:].squeeze()-ncifs['tmp'][:].squeeze()
    udiff1 = ncufs1['ugrd'][:].squeeze()-ncifs['ugrd'][:].squeeze()
    vdiff1 = ncufs1['vgrd'][:].squeeze()-ncifs['vgrd'][:].squeeze()
    # convert humidity to g/kg
    qdiff1 = 1000.*(ncufs1['spfh'][:].squeeze()-ncifs['spfh'][:].squeeze())
    tmpdiff2 = ncufs2['tmp'][:].squeeze()-ncifs['tmp'][:].squeeze()
    udiff2 = ncufs2['ugrd'][:].squeeze()-ncifs['ugrd'][:].squeeze()
    vdiff2 = ncufs2['vgrd'][:].squeeze()-ncifs['vgrd'][:].squeeze()
    qdiff2 = 1000.*(ncufs2['spfh'][:].squeeze()-ncifs['spfh'][:].squeeze())
    ncufs1.close(); ncufs2.close(); ncifs.close()

    tmperrsq1 += getmean(tmpdiff1**2,coslats)/len(dates)
    tmpbias1  += getmean(tmpdiff1,coslats)/len(dates)
    qerrsq1 += getmean(qdiff1**2,coslats)/len(dates)
    qbias1  += getmean(qdiff1,coslats)/len(dates)
    windrms1 += np.sqrt(getmean(udiff1**2,coslats) + getmean(vdiff1**2,coslats))/len(dates)
    tmperrsq2 += getmean(tmpdiff2**2,coslats)/len(dates)
    tmpbias2  += getmean(tmpdiff2,coslats)/len(dates)
    qerrsq2 += getmean(qdiff2**2,coslats)/len(dates)
    qbias2  += getmean(qdiff2,coslats)/len(dates)
    windrms2 += np.sqrt(getmean(udiff2**2,coslats) + getmean(vdiff2**2,coslats))/len(dates)

tmprms1 = np.sqrt(tmperrsq1); tmprms2 = np.sqrt(tmperrsq2)
qrms1 = np.sqrt(qerrsq1); qrms2 = np.sqrt(qerrsq2)
ptop = 100. # top of plot
nlevtop =  np.argwhere(plevs_mid < ptop)[0,0]

color1 = 'r'; linewidth1 = 1.0
color2 = 'b'; linewidth2 = 1.0

fig = plt.figure(figsize=(11,6))
fig.add_subplot(1,3,1)
plt.plot(windrms1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(windrms2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
plt.ylabel('pressure')
plt.title('vector wind: %s' % region)
plt.xlabel('RMS (mps)')
plt.axis('tight')
#plt.xlim(2.0,3.75)
plt.ylim(1000,ptop)
plt.grid(True)

plt.subplot(1,3,2)
plt.plot(tmprms1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(tmprms2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
plt.xlabel('RMS (K)')
plt.title('temp: %s' % region)
plt.axis('tight')
#plt.xlim(0.25,1.5)
plt.ylim(1000,ptop)
plt.grid(True)

fig.add_subplot(1,3,3)
plt.plot(qrms1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(qrms2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
plt.xlabel('RMS (g/kg)')
plt.legend(loc=0)
plt.title('spfh: %s' % region)
locator = matplotlib.ticker.MaxNLocator(nbins=4)
plt.gca().xaxis.set_major_locator(locator)
plt.axis('tight')
#plt.xlim(0.0,1.5)
plt.ylim(1000,ptop)
plt.grid(True)

plt.figtext(0.5,0.93,'12-h ens mean fcst RMS vs IFS %s-%s' % (date1,date2),horizontalalignment='center',fontsize=18)
plt.savefig('ifsdiffrms_%s_%s_%s.png' % (expt1,expt2,region))

fig = plt.figure(figsize=(11,6))
fig.add_subplot(1,2,1)
plt.plot(tmpbias1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(tmpbias2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
plt.xlabel('bias (K)')
plt.title('temp: %s' % region)
plt.axis('tight')
#plt.xlim(-0.25,0.25)
plt.ylim(1000,ptop)
plt.axvline(0)
plt.grid(True)

fig.add_subplot(1,2,2)
plt.plot(qbias1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(qbias2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
plt.xlabel('bias (g/kg)')
plt.legend(loc=0)
plt.title('spfh: %s' % region)
locator = matplotlib.ticker.MaxNLocator(nbins=4)
plt.gca().xaxis.set_major_locator(locator)
plt.axis('tight')
#plt.xlim(-0.5,0.5)
plt.ylim(1000,ptop)
plt.axvline(0)
plt.grid(True)

plt.figtext(0.5,0.93,'12-h ens mean fcst bias vs IFS %s-%s' % (date1,date2),horizontalalignment='center',fontsize=18)
plt.savefig('ifsdiffbias_%s_%s_%s.png' % (expt1,expt2,region))

plt.show()
