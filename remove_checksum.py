"""remove checksums from fv3 restart files"""
from netCDF4 import Dataset
import sys, os
datapath = sys.argv[1]
for tile in ['tile1','tile2','tile3','tile4','tile5','tile6']:
    for ftype in ['fv_core','fv_tracer','fv_srf_wnd','sfc_data','phy_data']: 
        if ftype in ['sfc_data','phy_data']:
            nc = Dataset(os.path.join(datapath,'%s.%s.nc' % (ftype,tile)),'a')
        else:
            nc = Dataset(os.path.join(datapath,'%s.res.%s.nc' % (ftype,tile)),'a')
        for var in nc.variables.values():
            if hasattr(var,'checksum'):
                var.delncattr('checksum')
        nc.close()
