"""plot profiles of rms/bias relative to IFS analyses"""
import matplotlib
matplotlib.use('Agg')
from netCDF4 import Dataset
import numpy as np
import matplotlib.pyplot as plt
import os,sys,dateutils
from scipy import stats

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    mean = np.empty(diff.shape[0],diff.dtype)
    for k in range(diff.shape[0]):
        mean[k] = (coslats*diff[k]).mean()/meancoslats
    return mean[::-1]

def ttest(data1, data2, inflate=False):
    # calculate means
    mean1 = data1.mean(axis=0); mean2 = data2.mean(axis=0)
    # number of paired samples
    n = data1.shape[0]
    # sum squared difference between observations
    d1 = ((data1-data2)**2).sum(axis=0)
    # sum difference between observations
    d2 = (data1-data2).sum(axis=0)
    # standard deviation of the difference between means
    sd = np.sqrt((d1 - (d2**2 / n)) / (n - 1))
    # standard error of the difference between the means
    inflation = 1.0
    if inflate:
        # inflation to represent autocorrelation (see Geer 2016 appendix, Wilks 2006)
        x = data1-data2
        r1 = np.empty(data1.shape[1])
        r2 = np.empty(data1.shape[1])
        for i in range(data1.shape[1]):
            r1[i] = np.corrcoef(x[:-1,i], x[1:,i],rowvar=False)[0,1]
            r2[i] = np.corrcoef(x[:-2,i], x[2:,i],rowvar=False)[0,1]
        #r2 = r1 # AR(1)
        phi1 = r1*(1.-r2)/(1.-r1**2)
        phi2 = (r2-r1**2)/(1.-r1**2)
        rho1  = phi1/(1.-phi2)
        rho2 = phi2 + phi1**2/(1.-phi2)
        inflation = np.sqrt((1.-rho1*phi1-rho2*phi2)/(1.-phi1-phi2)**2)
        inflation = np.where(inflation < 1.0, 1.0, inflation)
    sed = inflation*sd / np.sqrt(n)
    # calculate the t statistic
    t_stat = (mean1 - mean2) / sed
    # return the p-values
    return 1.-(1.-stats.t.cdf(abs(t_stat), n-1)) * 2.0 # two sided

def ttest2(data1,data2):
    t, p = stats.ttest_rel(data1,data2)
    return 1.-p

date1 = sys.argv[1]
date2 = sys.argv[2]
expt1 = sys.argv[3]
expt2 = sys.argv[4]
region = sys.argv[5] # "NH", "TR" or "GL"

latbound = 20.
ifsanldir = '/scratch2/NCEPDEV/stmp1/Jeffrey.S.Whitaker/era5anl/ufs'
expbasedir = '/scratch2/BMC/gsienkf/whitaker'

dates = dateutils.daterange(date1,date2,6)
coslats = None

sigthresh = 0.99       # significance threshold (p-value)
hr=6
prefix1='sfg2'
prefix2='sfg'

RES=None
LEVS=None

tmperrsq1ts = []
tmperrsq2ts = []
windrms1ts = []
windrms2ts = []
qerrsq1ts = []
qerrsq2ts = []
ncount=0
for date in dates:
    #datev = dateutils.dateshift(date,hr)
    datev = date
    exptdir1 = os.path.join(expbasedir+'/'+expt1,datev)
    exptdir2 = os.path.join(expbasedir+'/'+expt2,datev)
    ufsfcst1 = os.path.join(exptdir1,'%s_%s_fhr%02i_ensmean'%(prefix1,datev,hr))
    ufsfcst2 = os.path.join(exptdir2,'%s_%s_fhr%02i_ensmean'%(prefix2,datev,hr))
    ncufs1 = Dataset(ufsfcst1)
    ncufs2 = Dataset(ufsfcst2)
    if LEVS is None:
        LEVS=len(ncufs1.dimensions['pfull'])
    if RES is None:
        RES=len(ncufs1.dimensions['grid_xt'])//4
    ifsanl = os.path.join(ifsanldir,'C%sL%s_ifsanl_%s.nc'% (RES,LEVS,datev))
    ncifs = Dataset(ifsanl)
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
        plevs_up = plevs[1:]; plevs_dn = plevs[:-1] 
        plevs_mid = 0.5*(plevs[1:]+plevs[:-1]) # mid-levels
        nlevs = len(plevs_mid)
        tmperrsq1=np.zeros(nlevs); tmperrsq2 = np.zeros(nlevs)
        tmpbias1=np.zeros(nlevs); tmpbias2 = np.zeros(nlevs)
        qerrsq1=np.zeros(nlevs); qerrsq2 = np.zeros(nlevs)
        qbias1=np.zeros(nlevs); qbias2 = np.zeros(nlevs)
        windrms1=np.zeros(nlevs); windrms2 = np.zeros(nlevs)
           
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

    tmperrsq = getmean(tmpdiff1**2,coslats)
    tmperrsq1ts.append(tmperrsq)
    tmperrsq1 += tmperrsq/len(dates)
    tmpbias1  += getmean(tmpdiff1,coslats)/len(dates)
    qerrsq = getmean(qdiff1**2,coslats)
    qerrsq1 += qerrsq/len(dates)
    qerrsq1ts.append(qerrsq)
    qbias1  += getmean(qdiff1,coslats)/len(dates)
    windrms = np.sqrt(getmean(udiff1**2,coslats) + getmean(vdiff1**2,coslats))
    windrms1ts.append(windrms)
    windrms1 += windrms/len(dates)
    tmperrsq = getmean(tmpdiff2**2,coslats)
    tmperrsq2ts.append(tmperrsq)
    tmperrsq2 += tmperrsq/len(dates)
    tmpbias2  += getmean(tmpdiff2,coslats)/len(dates)
    qerrsq = getmean(qdiff2**2,coslats)
    qerrsq2ts.append(qerrsq)
    qerrsq2 += qerrsq/len(dates)
    qbias2  += getmean(qdiff2,coslats)/len(dates)
    windrms = np.sqrt(getmean(udiff2**2,coslats) + getmean(vdiff2**2,coslats))
    windrms2ts.append(windrms)
    windrms2 += windrms/len(dates)
    ncount += 1
    print(date, windrms1.mean()*len(dates)/ncount, windrms2.mean()*len(dates)/ncount)

tmprms1 = np.sqrt(tmperrsq1); tmprms2 = np.sqrt(tmperrsq2)
qrms1 = np.sqrt(qerrsq1); qrms2 = np.sqrt(qerrsq2)
ptop = 100. # top of plot
nlevtop =  np.argwhere(plevs_mid < ptop)[0,0]

tmperrsq1ts = np.array(tmperrsq1ts)
tmperrsq2ts = np.array(tmperrsq2ts)
tmperrsq_pval = ttest(tmperrsq1ts,tmperrsq2ts,inflate=True)
sigtmp = tmperrsq_pval >= sigthresh

qerrsq1ts = np.array(qerrsq1ts)
qerrsq2ts = np.array(qerrsq2ts)
qerrsq_pval = ttest(qerrsq1ts,qerrsq2ts,inflate=True)
sigq = qerrsq_pval >= sigthresh

windrms1ts = np.array(windrms1ts)
windrms2ts = np.array(windrms2ts)
windrms_pval = ttest(windrms1ts,windrms2ts,inflate=True)
sigwind = windrms_pval >= sigthresh

color1 = 'r'; linewidth1 = 1.0
color2 = 'b'; linewidth2 = 1.0

fig = plt.figure(figsize=(11,6))
fig.add_subplot(1,3,1)
plt.plot(windrms1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(windrms2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
for n in range(nlevtop):
    if sigwind[n]:
        plt.axhspan(plevs_up[n], plevs_dn[n], facecolor='lightgoldenrodyellow')
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
for n in range(nlevtop):
    if sigtmp[n]:
        plt.axhspan(plevs_up[n], plevs_dn[n], facecolor='lightgoldenrodyellow')
plt.xlabel('RMS (K)')
plt.title('temp: %s' % region)
plt.axis('tight')
#plt.xlim(0.25,1.5)
plt.ylim(1000,ptop)
plt.grid(True)

fig.add_subplot(1,3,3)
plt.plot(qrms1[:nlevtop],plevs_mid[:nlevtop],color=color1,linewidth=linewidth1,label=expt1)
plt.plot(qrms2[:nlevtop],plevs_mid[:nlevtop],color=color2,linewidth=linewidth2,label=expt2)
for n in range(nlevtop):
    if sigq[n]:
        plt.axhspan(plevs_up[n], plevs_dn[n], facecolor='lightgoldenrodyellow')
plt.xlabel('RMS (g/kg)')
plt.legend(loc=0)
plt.title('spfh: %s' % region)
locator = matplotlib.ticker.MaxNLocator(nbins=4)
plt.gca().xaxis.set_major_locator(locator)
plt.axis('tight')
#plt.xlim(0.0,1.5)
plt.ylim(1000,ptop)
plt.grid(True)

plt.figtext(0.5,0.93,'%s-h ens mean fcst RMS vs IFS %s-%s' % (hr, date1,date2),horizontalalignment='center',fontsize=18)
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

plt.figtext(0.5,0.93,'%s-h ens mean fcst bias vs IFS %s-%s' % (hr,date1,date2),horizontalalignment='center',fontsize=18)
plt.savefig('ifsdiffbias_%s_%s_%s.png' % (expt1,expt2,region))

plt.show()
