from __future__ import print_function
import ncepbufr, sys
import numpy as np

hdstr='YEAR MNTH DAYS HOUR MINU RPID WMOB WMOS CLAT CLON SELV TMDB TMDP REHU'
#hdstr='RCYR RCMO RCDY RCHR RCMI'

# read adpsc bufr file, extract temp obs

bufr = ncepbufr.open(sys.argv[1])
print('station_id, lon, lat, date, elevation, sens temp, dew pt temp')
while bufr.advance() == 0: # loop over messages.
    #print(bufr.msg_counter, bufr.msg_type, bufr.msg_date, bufr.receipt_time)
    while bufr.load_subset() == 0: # loop over subsets in message.
        hdr = bufr.read_subset(hdstr).squeeze()
        station_id = hdr[5].tostring().decode("utf-8") 
        lat = hdr[8]; lon = hdr[9]; elev = hdr[10]
        date = '%04i%02i%02i%02i%02i' % (hdr[0],hdr[1],hdr[2],hdr[3],hdr[4])
        wmob = hdr[6]; wmoc = hdr[7]
        tsen = hdr[11]
        tdew = hdr[12]
        print('%s %7.2f %6.2f %s %7.2f %6.2f %6.2f' % 
        (station_id,lon,lat,date,elev,tsen,tdew))
bufr.close()
