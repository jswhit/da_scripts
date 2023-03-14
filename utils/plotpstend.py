import matplotlib as mpl
mpl.use('agg')
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime

pstend1 = np.loadtxt('pstend.txt')
pstend2 = np.loadtxt('pstend.txt')
dates1 = [datetime.strptime(str(dateint),'%Y%m%d%H') for dateint in pstend1[:,0].astype('i')]
dates2 = [datetime.strptime(str(dateint),'%Y%m%d%H') for dateint in pstend2[:,0].astype('i')]
expt1 = pstend1[:,1]; expt2 = pstend2[:,1]
expt1name = 'hybrid gain'; expt2name = 'hybrid cov'

fig = plt.figure(figsize=(14,12))
fig.subplots_adjust(bottom=0.2)
ax = fig.add_subplot(1,1,1)
    

dateFmt = mpl.dates.DateFormatter('%m-%d-%H')
daysLoc = mpl.dates.HourLocator(interval=12)
hoursLoc = mpl.dates.HourLocator(interval=12)
daysLoc = mpl.dates.HourLocator(interval=12)
hoursLoc = mpl.dates.HourLocator(interval=12)
ax.xaxis.set_major_formatter(dateFmt)
ax.xaxis.set_major_locator(daysLoc)
ax.xaxis.set_minor_locator(hoursLoc)
plt.plot(dates1,expt1,label='%s (mean = %5.3f)'
        % (expt1name,expt1.mean()),color='r',linewidth=2,linestyle='-',marker='o')
plt.plot(dates2,expt2,label='%s (mean = %5.3f)'
        % (expt2name,expt2.mean()),color='b',linewidth=2,linestyle='-',marker='o')
plt.autoscale(enable=True, axis='x', tight=True)
plt.legend(loc=4)
ax = plt.gca()
plt.setp(ax.get_xticklabels(), 'rotation', 90,
         'horizontalalignment', 'center', fontsize=16)
plt.ylabel('Mean Abs PStend (hPa/hr) for fhr=1',fontsize=20,fontweight='bold')
plt.xlabel('analysis time',fontsize=20,fontweight='bold')
plt.ylim(0.0,1.5)
plt.grid(True)
plt.savefig('pstend.png')
plt.show()
