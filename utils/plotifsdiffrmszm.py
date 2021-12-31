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
    return mean.mean()

def ttest(data1, data2, AR1=False):
    # 1st dimension of data1 and data2 is vertical level, second is time.
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
    # inflation to represent autocorrelation (see Geer 2016 appendix, Wilks 2006)
    # (https://doi.org/10.3402/tellusa.v68.30229)
    x = data1-data2
    if x.ndim != 3:
        raise ValueError('3d input expected in ttest')
    ntimes = data1.shape[0]
    nlevs = data1.shape[1]
    nlats = data1.shape[2]
    r1 = np.empty((nlevs,nlats),dtype=np.float64)
    r2 = np.empty((nlevs,nlats),dtype=np.float64)
    for j in range(nlats):
        for i in range(nlevs):
            r1[i,j] = np.corrcoef(x[:-1,i,j], x[1:,i,j],rowvar=False)[0,1]
            r2[i,j] = np.corrcoef(x[:-2,i,j], x[2:,i,j],rowvar=False)[0,1]
    if AR1:
       r2 = r1 
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
    return 1.-(1.-stats.t.cdf(np.abs(t_stat), n-1)) * 2.0 # two-sided

label1 = sys.argv[1]
label2 = sys.argv[2]

nc_expt1 = Dataset('ifsdiff_%s_zonalmean.nc' % label1)
nc_expt2 = Dataset('ifsdiff_%s_zonalmean.nc' % label2)

plevs_mid = nc_expt1['plevs_mid'][:]
plevs_up = nc_expt1['plevs_up'][:]
plevs_dn = nc_expt1['plevs_down'][:]
times = nc_expt1['time'][:].astype(np.int32)
dates = [dateutils.hrstodate(time) for time in times] 
dates_txt = '%s-%s' % (dates[0],dates[-1])
hr = nc_expt1.fhour

tmperrsq1 = nc_expt1['temperr'][:]
tmpbias1 = nc_expt1['tempbias'][:]
qerrsq1 = nc_expt1['qerr'][:]
qbias1 = nc_expt1['qbias'][:]
winderrsq1 = nc_expt1['winderr'][:]
tmperrsq2 = nc_expt2['temperr'][:]
tmpbias2 = nc_expt2['tempbias'][:]
qerrsq2 = nc_expt2['qerr'][:]
qbias2 = nc_expt2['qbias'][:]
winderrsq2 = nc_expt2['winderr'][:]
ntimes, nlevs, nlats = winderrsq2.shape
lats = nc_expt1['lat'][:]
coslats = np.cos(np.radians(lats))

nc_expt1.close(); nc_expt2.close()

sigthresh = 0.95       # significance threshold (p-value)
ptop = 150.
nlevtop =  np.argwhere(plevs_mid < ptop)[0,0]

tmperrsq_pval = ttest(tmperrsq1[:,:nlevtop,:],tmperrsq2[:,:nlevtop,:],AR1=False)
sigtmp = tmperrsq_pval >= sigthresh
winderrsq_pval = ttest(winderrsq1[:,:nlevtop,:],winderrsq2[:,:nlevtop,:],AR1=False)
sigwind = winderrsq_pval >= sigthresh

#fig = plt.figure(figsize=(11,6))
#fig.add_subplot(1,3,1)
windrms1 = np.sqrt(winderrsq1.mean(axis=0))[:nlevtop]
windrms2 = np.sqrt(winderrsq2.mean(axis=0))[:nlevtop]
tmprms1 = np.sqrt(tmperrsq1.mean(axis=0))[:nlevtop]
tmprms2 = np.sqrt(tmperrsq2.mean(axis=0))[:nlevtop]
windrms1mean = getmean(windrms1,coslats)
windrms2mean = getmean(windrms2,coslats)
tmprms1mean = getmean(tmprms1,coslats)
tmprms2mean = getmean(tmprms2,coslats)
plevs_mid=plevs_mid[:nlevtop]
print('vertically integrated wind rms diff (%s,%s) = ' % (label1,label2),windrms1mean,windrms2mean)
print('vertically integrated temp rms diff (%s,%s) = ' % (label1,label2),tmprms1mean,tmprms2mean)

date1 = dates[0]; date2 = dates[-1]
fig = plt.figure(figsize=(10,12))
fig.add_subplot(2,1,1)
rmsdiff = windrms1-windrms2
print(rmsdiff.min(), rmsdiff.max())
clevs = np.arange(-0.5,0.51,0.05)
clevsneg = clevs[clevs < 0]
clevspos = clevs[clevs > 0]
plt.contour(lats,plevs_mid,rmsdiff,clevsneg,colors='k',linewidths=0.5,linestyles='dotted')
plt.contour(lats,plevs_mid,rmsdiff,[0],colors='k',linewidths=1.0)
plt.contour(lats,plevs_mid,rmsdiff,clevspos,colors='k',linewidths=0.5)
rmsdiff = np.ma.array(rmsdiff,mask=np.logical_not(sigwind))
plt.contourf(lats,plevs_mid,rmsdiff,clevs,cmap=plt.cm.bwr,extend='both')
plt.colorbar()
plt.ylim(plevs_mid[0],plevs_mid[-1])
plt.gca().set_xticks([-90,-60,-30,0,30,60,90])
plt.grid(True)
plt.title('Vector Wind (mean = %5.2f mps)' % (windrms1mean-windrms2mean),fontsize=14)
plt.xlabel('nominal pressure (hPa)')
plt.ylabel('latitude (degrees)')

fig.add_subplot(2,1,2)
rmsdiff = tmprms1-tmprms2
print(rmsdiff.min(), rmsdiff.max())
plt.contour(lats,plevs_mid,rmsdiff,clevsneg,colors='k',linewidths=0.5,linestyles='dotted')
plt.contour(lats,plevs_mid,rmsdiff,[0],colors='k',linewidths=1.0)
plt.contour(lats,plevs_mid,rmsdiff,clevspos,colors='k',linewidths=0.5)
rmsdiff = np.ma.array(rmsdiff,mask=np.logical_not(sigtmp))
plt.contourf(lats,plevs_mid,rmsdiff,clevs,cmap=plt.cm.bwr,extend='both')
plt.colorbar()
plt.ylim(plevs_mid[0],plevs_mid[-1])
plt.gca().set_xticks([-90,-60,-30,0,30,60,90])
plt.grid(True)
plt.title('Temp (mean = %5.2f K)' % (tmprms1mean-tmprms2mean),fontsize=14)
plt.xlabel('nominal pressure (hPa)')
plt.ylabel('latitude (degrees)')

plt.figtext(0.5,0.93,'%s-h ens mean fcst vs IFS (%s-%s)  %s-%s' % (hr,label1,label2,date1,date2),horizontalalignment='center',fontsize=12)

plt.savefig('test.png')
#plt.savefig('ifsdiffrmsv_%s_%s_zonalmean.png' % (label1,label2))
