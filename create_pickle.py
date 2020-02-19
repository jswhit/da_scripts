from __future__ import print_function
from netCDF4 import Dataset
import numpy as np
import sys, time
from stripack import trmesh
try:
    import cPickle
except:
    import _pickle as cPickle

# test fv3 interpolation from native history files to random points.

res = int(sys.argv[1])
fixfv3 = '/work/noaa/gsienkf/whitaker/fix/fix_fv3_gmted2010'
# perform triangulation.
lons = []; lats = []
for ntile in range(1,7,1):
    gridfile = '%s/C%s/C%s_grid.tile%s.nc'% (fixfv3,res,res,ntile)
    nc = Dataset(gridfile)
    lonsmid = nc['x'][1::2,1::2]
    latsmid = nc['y'][1::2,1::2]
    lons.append(lonsmid); lats.append(latsmid)
    nc.close()
lons = np.radians(np.array(lons,dtype=np.float64)).ravel()
lats = np.radians(np.array(lats,dtype=np.float64)).ravel()
t1 = time.clock()
print('triangulation of', len(lons),' points')
tri = trmesh(lons, lats)
print('triangulation took',time.clock()-t1,' secs')

# pickle it.
picklefile = 'C%s_grid.pickle' % res
cPickle.dump(tri,open(picklefile,'wb'),-1)
