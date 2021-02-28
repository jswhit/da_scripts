from __future__ import print_function
from netCDF4 import Dataset
import numpy as np
import sys
nc1 = Dataset(sys.argv[1])
nc2 = Dataset(sys.argv[2])
for varname in nc1.variables.keys():
    data1 = nc1[varname][:]
    data2 = nc2[varname][:]
    diff = data2-data1
    print('%s min/max 1=%s,%s min/max 2=%s,%s max abs diff=%s'%(varname, data1.min(), data2.max(), data2.min(), data2.max(), (np.abs(diff)).max()))
