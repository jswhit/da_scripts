# read(lunin,101) s_ens_hv(k), s_ens_vv(k), beta_s(k), beta_e(k)
# 101 format(F8.1,3x,F8.3,F8.4,3x,F8.4)
import sys
import numpy as np
datain = np.loadtxt(sys.argv[1],skiprows=1)
s_ens_h = datain[:,0]/np.sqrt(2.)
s_ens_v = datain[:,1]
beta_static  = datain[:,2]
beta_ens  = datain[:,3]
fout = open(sys.argv[2],'w')
nlevs = len(s_ens_v)
fout.write('%s\n' % nlevs)
for nlev in range(nlevs):
    fout.write('%8.1f  %8.3f %8.4f   %8.4f\n' % (s_ens_h[nlev],s_ens_v[nlev],beta_static[nlev],beta_ens[nlev]))
