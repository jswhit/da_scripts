from __future__ import print_function
from netCDF4 import Dataset
from cftime import _parse_date
import sys
filename = sys.argv[1]
nc = Dataset(filename)
time_units = nc['time'].units
date_str = time_units.split('since ')[1]
YYYYMMDDHH = '%04i%02i%02i%02i' % _parse_date(date_str)[0:4]
nfhour = int(nc['time'][0])
print('%s %s' % (YYYYMMDDHH,nfhour))
