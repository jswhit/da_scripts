import matplotlib as mpl
mpl.use('agg')
import matplotlib.pyplot as plt
import numpy as np
from dateutils import datetohrs

pstend1 = np.loadtxt('pstend_hybgain.out')
pstend2 = np.loadtxt('pstend_hybcov.out')
dates1 = pstend1[:,0]
dates2 = pstend2[:,0]
expt1 = pstend1[:,1]; expt2 = pstend2[:,1]
expt1name = 'hybrid gain'; expt2name = 'hybrid cov'

fig = plt.figure(figsize=(14,12))
fig.subplots_adjust(bottom=0.2)
ax = fig.add_subplot(1,1,1)

times1 = [float(datetohrs(str(date),mixedcal=False))/24. for date in dates1]
times2 = [float(datetohrs(str(date),mixedcal=False))/24. for date in dates2]
dateFmt = mpl.dates.DateFormatter('%m-%d-%H')
daysLoc = mpl.dates.HourLocator(interval=3)
hoursLoc = mpl.dates.HourLocator(interval=3)
daysLoc = mpl.dates.HourLocator(interval=3)
hoursLoc = mpl.dates.HourLocator(interval=3)
ax.xaxis.set_major_formatter(dateFmt)
ax.xaxis.set_major_locator(daysLoc)
ax.xaxis.set_minor_locator(hoursLoc)
plt.plot_date(times1,expt1,label='%s (mean = %5.3f)'
        % (expt1name,expt1.mean()),color='r',linewidth=2,linestyle='-',marker='o')
plt.plot_date(times2,expt2,label='%s (mean = %5.3f)'
        % (expt2name,expt2.mean()),color='b',linewidth=2,linestyle='-',marker='o')
plt.autoscale(enable=True, axis='x', tight=True)
plt.legend(loc=4)
ax = plt.gca()
plt.setp(ax.get_xticklabels(), 'rotation', 90,
         'horizontalalignment', 'center', fontsize=16)
#plt.title('Z500 F120 %s' % hem, fontsize=24,fontweight='bold')
plt.ylabel('Mean Abs PStend (hPa/hr) for fhr=1',fontsize=20,fontweight='bold')
plt.xlabel('analysis time',fontsize=20,fontweight='bold')
#plt.ylim(0.0,1.5)
plt.grid(True)
plt.savefig('pstend.png')
plt.show()
