from __future__ import print_function
import ncepbufr, sys, os
import numpy as np

filename = sys.argv[1]
filenameout = sys.argv[2]

hdstr='SID XOB YOB DHR TYP ELV SAID T29'
obstr='POB QOB TOB ZOB UOB VOB PWO MXGS HOVI CAT PRSS TDO PMO'
qcstr='PQM QQM TQM ZQM WQM NUL PWQ PMQ'
oestr='POE QOE TOE NUL WOE NUL PWE'

bufr = ncepbufr.open(filename)
f = open(filenameout,'w')
f.write('#station_id station_type lon lat time_offset elev qob tob tdob\n')
while bufr.advance() == 0: # loop over messages.
    while bufr.load_subset() == 0: # loop over subsets in message.
        hdr = bufr.read_subset(hdstr).squeeze()
        lon = hdr[1]; lat = hdr[2]; time = hdr[3]; elev = hdr[5]
        station_id = hdr[0].tobytes().decode('utf-8')
        station_type = int(hdr[4])
        if station_type > 180 and station_type < 200 and stelev < 9998:
            obs = bufr.read_subset(obstr)
            oer = bufr.read_subset(oestr)
            qcf = bufr.read_subset(qcstr)
            f.write('%3i %s %6.2f %6.2f %6.2f %6.1f %7.1f %6.2f %6.2f\n' % (station_type,station_id,lat,lon,time,elev,obs[1,0],273.15+obs[2,0],273.15+obs[11,0]))
f.close()
