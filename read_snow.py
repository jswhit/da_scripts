from __future__ import print_function
import ncepbufr, sys
import numpy as np

hdstr='YEAR MNTH DAYS HOUR MINU RPID WMOB WMOS CLAT CLON SELV TOSD DOFS SOGR'
#hdstr='RCYR RCMO RCDY RCHR RCMI'

# read adpsc bufr file, extract snow obs

bufr = ncepbufr.open(sys.argv[1])
print('station_id, lon, lat, date, elevation, total snow depth (m)')
while bufr.advance() == 0: # loop over messages.
    #print(bufr.msg_counter, bufr.msg_type, bufr.msg_date, bufr.receipt_time)
    while bufr.load_subset() == 0: # loop over subsets in message.
        hdr = bufr.read_subset(hdstr).squeeze()
        station_id = hdr[5].tostring()
        lat = hdr[8]; lon = hdr[9]; elev = hdr[10]
        date = '%04i%02i%02i%02i%02i' % (hdr[0],hdr[1],hdr[2],hdr[3],hdr[4])
        wmob = hdr[6]; wmoc = hdr[7]
        total_snow_depth = hdr[11]
        depth_fresh_snow = hdr[12]
        ground_state = hdr[13]
        if total_snow_depth > 0:
            print('%s %9.4f %8.4f %s %4i %4.2f' % 
            (station_id,lon,lat,date,elev,total_snow_depth))
bufr.close()
