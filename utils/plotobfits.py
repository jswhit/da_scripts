import matplotlib
matplotlib.use('Agg')
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import rcParams
import dateutils, sys
from netCDF4 import Dataset
from scipy import stats

levtop=125; levbot=925 # plot limits
sigthresh = 0.99       # significance threshold (p-value)
umin=2.5; umax=4.0
tmin=0.5; tmax=1.4
#umin=2.75; umax=4.5
#tmin=0.7; tmax=1.6

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

color1 = 'r'; linewidth1 = 1.0
color2 = 'b'; linewidth2 = 1.0

obtypes = 'All Insitu'

expt1=sys.argv[1]
expt2=sys.argv[2]
title=sys.argv[3]
region=sys.argv[4]

rcParams['figure.subplot.left'] = 0.1 
rcParams['figure.subplot.top'] = 0.85 
rcParams['legend.fontsize']=12

nc_expt1 = Dataset(expt1+'.nc','r')
nc_expt2 = Dataset(expt2+'.nc','r')
levels = nc_expt1['plevs'][:]
levels_up = nc_expt1['plevs_up'][:]
levels_down = nc_expt1['plevs_down'][:]
times = nc_expt1['times'][:].astype(np.int32)
dates = [dateutils.hrstodate(time) for time in times] 
dates_txt = '%s-%s' % (dates[0],dates[-1])
wind_counts1 = nc_expt1['wind_obcounts'][:]
temp_counts1 = nc_expt1['temp_obcounts'][:]
temp_fits1 = nc_expt1['omf_rmstemp'][:]
temp_bias1 = nc_expt1['omf_biastemp'][:]
wind_fits1  = nc_expt1['omf_rmswind'][:]
temp_fits2 = nc_expt2['omf_rmstemp'][:]
temp_bias2 = nc_expt2['omf_biastemp'][:]
wind_fits2  = nc_expt2['omf_rmswind'][:]
#print(wind_fits1.mean(axis=0))
#print(wind_fits2.mean(axis=0))
#raise SystemExit

fig = plt.figure(figsize=(8,6))
plt.subplot(1,2,1)
wind_fits1mean = wind_fits1.mean(axis=0)
wind_fits2mean = wind_fits2.mean(axis=0)
wind_fits_pval = ttest(wind_fits1,wind_fits2,inflate=True)
sig = wind_fits_pval >= sigthresh
plt.plot(wind_fits1mean,levels,color=color1,linewidth=linewidth1,marker='o',label=expt1)
plt.plot(wind_fits2mean,levels,color=color2,linewidth=linewidth2,marker='o',label=expt2)
for n in range(len(levels)):
    if sig[n]:
        plt.axhspan(levels_up[n], levels_down[n], facecolor='lightgoldenrodyellow')
plt.ylabel('pressure (hPa)')
plt.title('%s: %s' % (obtypes+' V',region))
plt.xlabel('RMS (mps)')
plt.axis('tight')
plt.xlim(umin,umax)
plt.ylim(levbot,levtop)
plt.grid(True)

plt.subplot(1,2,2)
temp_fits1mean = np.sqrt(temp_fits1).mean(axis=0)
temp_fits2mean = np.sqrt(temp_fits2).mean(axis=0) 
temp_fits_pval = ttest(temp_fits1,temp_fits2,inflate=True)
sig = temp_fits_pval >= sigthresh
plt.plot(temp_fits1mean,levels,color=color1,linewidth=linewidth1,marker='o',label=expt1)
plt.plot(temp_fits2mean,levels,color=color2,linewidth=linewidth2,marker='o',label=expt2)
for n in range(len(levels)):
    if sig[n]:
        plt.axhspan(levels_up[n], levels_down[n], facecolor='lightgoldenrodyellow')
plt.xlabel('RMS (K)')
plt.title('%s: %s' % (obtypes+' T',region))
plt.axis('tight')
plt.xlim(tmin,tmax)
plt.ylim(levbot,levtop)
plt.grid(True)
plt.legend(loc=0)

plt.figtext(0.5,0.93,'%s RMS O-F (%s)' % (title,dates_txt),horizontalalignment='center',fontsize=18)
plt.savefig('obfits_%s_%s_%s.png' % (expt1,expt2,region))

plt.show()
