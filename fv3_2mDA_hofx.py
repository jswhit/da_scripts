from __future__ import print_function
import ncepbufr, sys, os
import numpy as np
import _pickle as cPickle
from netCDF4 import Dataset

bufrfilename = sys.argv[1]

def load_sfcobs(bufrfilename):
    hdstr='SID XOB YOB DHR TYP ELV SAID T29'
    obstr='POB QOB TOB ZOB UOB VOB PWO MXGS HOVI CAT PRSS TDO PMO'
    qcstr='PQM QQM TQM ZQM WQM NUL PWQ PMQ'
    oestr='POE QOE TOE NUL WOE NUL PWE'
    bufr = ncepbufr.open(bufrfilename)
    lats=[]; lons=[]; tdry = []; tdew = []; times = []; spfh = []; elev = []; stype = []
    while bufr.advance() == 0: # loop over messages.
        while bufr.load_subset() == 0: # loop over subsets in message.
            hdr = bufr.read_subset(hdstr).squeeze()
            station_type = int(hdr[4])
            if station_type > 180 and station_type < 200 and stelev < 9998:
                lon = hdr[1]; lat = hdr[2]; time = hdr[3]; stelev = hdr[5]
                obs = bufr.read_subset(obstr)
                #oer = bufr.read_subset(oestr)
                #qcf = bufr.read_subset(qcstr)
                tdry.append(273.15+obs[2,0])
                tdew.append(273.15+obs[11,0])
                spfh.append(273.15+obs[1,0])
                times.append(hdr[3])
    bufr.close()
    lats = np.ma.asarray(lats)
    lons = np.ma.asarray(lons)
    times = np.ma.asarray(times)
    elev = np.ma.asarray(elev)
    tdry = np.ma.asarray(tdry)
    tdew = np.ma.asarray(tdew)
    spfh = np.ma.asarray(spfh)
    return lats, lons, times, elev, tdry, tdew, spfh

def load_sfcobs_txt(bufrfilename):
    data = np.ma.masked_invalid(np.loadtxt(bufrfilename,usecols=(2,3,4,5,6,7,8)))
    lats = data[:,0]
    lons = data[:,1]
    times = data[:,2]
    elev = data[:,3]
    spfh = data[:,4]
    tdry = data[:,5]
    tdew = data[:,6]
    return lats, lons, times, elev, tdry, tdew, spfh

lats, lons, times, elev, tdry, tdew, spfh = load_sfcobs_txt(bufrfilename)


print(tdry.min(), tdry.max(),len(tdry), np.ma.count_masked(tdry))
print(tdew.min(), tdew.max(),len(tdew), np.ma.count_masked(tdew))
print(spfh.min(), spfh.max(),len(spfh), np.ma.count_masked(spfh))
lats = np.radians(lats); lons = np.radians(lons)


# load triangulation from from pickle
res = 192
picklefile = 'C%s_grid.pickle' % res
tri = cPickle.load(open(picklefile,'rb'))

# read data from history files.
def load_sfcgrid(datapath, var, charmem):
    data = []
    for ntile in range(1,7,1):
        datafile = '%s/%s/INPUT/sfc_data.tile%s.nc'% (datapath,charmem,ntile)
        nc = Dataset(datafile)
        data.append(nc[var][0,...])
        nc.close()
    return (np.array(data,dtype=np.float64)).ravel()

def load_3dgrid(datapath, var, charmem, nlev=1):
    data = []
    for ntile in range(1,7,1):
        datafile = '%s/%s/INPUT/fv_core.res.tile%s.nc'% (datapath,charmem,ntile)
        nc = Dataset(datafile)
        if nlev == None:
            data.append(nc[var][0,...])
        else:
            data.append(nc[var][0,nlev,...])
        nc.close()
    return (np.array(data,dtype=np.float64)).ravel()
    

datapath = '/scratch2/BMC/gsienkf/whitaker/C192_hybgain_2mDA/2020082012'
charmem='mem001'
t2m_guess = load_sfcgrid(datapath, 't2m', 'mem001')
orog_guess = load_3dgrid(datapath,'phis','mem001',nlev=None)/9.8066
# interpolate to obs points
tdry_guess = tri.interp_linear(lons,lats,t2m_guess)
elev_guess = tri.interp_linear(lons,lats,orog_guess)
elev_diff = elev_guess-elev
indx = np.abs(elev_diff) < 100

print(tdry_guess.min(), tdry_guess.max())
print(elev.min(), elev.max())
print(elev_guess.min(),elev_guess.max())
print(elev_diff.min(), elev_diff.max())
diff = tdry-tdry_guess
diffsq = (tdry-tdry_guess)**2
print(np.sqrt(diffsq.mean()))
