from netCDF4 import Dataset
import numpy as np
import os, sys, dateutils

msg = 'date1 date2 datapath runid hem outfile'
if len(sys.argv) < 6:
    print(msg)
    raise SystemExit

date1 = sys.argv[1] # date range
date2 = sys.argv[2]
datapath = sys.argv[3] # path to diag files.
runid = sys.argv[4] # suffix for diag file
hem = sys.argv[5] # NH,TR,SH,GL
outfile = sys.argv[6] # profile stats saved here
sondesonly = False # use only 120,132,220,221,232 (sondes,pibals,drops)
noair = False
latbound = 30
# if sondesonly False, aircraft, pibals and surface data included also

dates = dateutils.daterange(date1,date2,6)
if '2016011518' in dates: dates.remove('2016011518')
deltap = 50.; pbot = 975
nlevs = 23
levs = np.zeros(nlevs, np.float)
levs1 = np.zeros(nlevs, np.float)
levs2 = np.zeros(nlevs, np.float)
levs[0:18] = pbot - deltap*np.arange(18)
levs1[0:18] = levs[0:18] + 0.5*deltap
levs2[0:18] = levs[0:18] - 0.5*deltap
levs1[18] = levs2[17]
levs2[18] = 70.; levs1[19] = 70.
levs2[19] = 50.; levs1[20] = 50.
levs2[20] = 30.; levs1[21] = 30.
levs2[21] = 10.; levs1[22] = 10.
levs2[22] = 0.
levs1[0] = 1200.
pbins = np.zeros(nlevs+1,np.float)
pbins[0:nlevs] = levs1; pbins[nlevs] = levs2[-1]
for nlev in range(18,nlevs):
    levs[nlev] = 0.5*(levs1[nlev]+levs2[nlev])

rms_wind = np.zeros(len(levs),np.float)
rms_temp = np.zeros(len(levs),np.float)
rms_humid = np.zeros(len(levs),np.float)
bias_temp = np.zeros(len(levs),np.float)
bias_humid = np.zeros(len(levs),np.float)
count_temp = np.zeros(len(levs),np.int)
count_humid = np.zeros(len(levs),np.int)
count_wind = np.zeros(len(levs),np.int)
rms_wind_meantot = []
rms_temp_meantot = []
rms_humid_meantot = []

ncout = Dataset(outfile+'.nc','w')
plevs = ncout.createDimension('plevs',len(levs))
times = ncout.createDimension('time',len(dates))
plevs = ncout.createVariable('plevs',np.float32,'plevs')
plevs_up = ncout.createVariable('plevs_up',np.float32,'plevs')
plevs_down = ncout.createVariable('plevs_down',np.float32,'plevs')
plevs_up[:] = levs2
plevs_down[:] = levs1
plevs[:]=levs
plevs.units = 'hPa'
times = ncout.createVariable('times',np.float64,'time')
times.units = 'hours since 01-01-01'
omf_wnd = ncout.createVariable('omf_rmswind',np.float32, ('time','plevs'))
omf_temp = ncout.createVariable('omf_rmstemp',np.float32, ('time','plevs'))
omf_tempb = ncout.createVariable('omf_biastemp',np.float32, ('time','plevs'))
temp_obcounts = ncout.createVariable('temp_obcounts',np.int32, ('time','plevs'))
wind_obcounts = ncout.createVariable('wind_obcounts',np.int32, ('time','plevs'))

#datapath2='/scratch3/BMC/gsienkf/whitaker/t1534_t574'

ndate = 0
for date in dates:
    times[ndate] = dateutils.datetohrs(date)
    if runid != '': 
        obsfile_uv = os.path.join(datapath,'%s/diag_conv_uv_ges.%s_%s.nc4' % (date,date,runid))
        obsfile_t  = os.path.join(datapath,'%s/diag_conv_t_ges.%s_%s.nc4' % (date,date,runid))
        obsfile_q  = os.path.join(datapath,'%s/diag_conv_q_ges.%s_%s.nc4' % (date,date,runid))
    else:
        obsfile_uv = os.path.join(datapath,'%s/diag_conv_uv_ges.%s.nc4' % (date,date))
        obsfile_t  = os.path.join(datapath,'%s/diag_conv_t_ges.%s.nc4' % (date,date))
        obsfile_q  = os.path.join(datapath,'%s/diag_conv_q_ges.%s.nc4' % (date,date))
    nc_uv = Dataset(obsfile_uv); nc_t = Dataset(obsfile_t); nc_q = Dataset(obsfile_q)
    uv_code = nc_uv['Observation_Type'][:]
    t_code = nc_t['Observation_Type'][:]
    q_code = nc_q['Observation_Type'][:]
    uv_used = nc_uv['Analysis_Use_Flag'][:]
    t_used = nc_t['Analysis_Use_Flag'][:]
    q_used = nc_q['Analysis_Use_Flag'][:]
    uv_oberrinv = nc_uv['Errinv_Final'][:]
    t_oberrinv = nc_t['Errinv_Final'][:]
    q_oberrinv = nc_q['Errinv_Final'][:]
    uv_press = nc_uv['Pressure'][:]
    t_press = nc_t['Pressure'][:]
    q_press = nc_q['Pressure'][:]
    uv_lon = nc_uv['Longitude'][:]
    t_lon = nc_t['Longitude'][:]
    q_lon = nc_q['Longitude'][:]
    uv_lat = nc_uv['Latitude'][:]
    t_lat = nc_t['Latitude'][:]
    q_lat = nc_q['Latitude'][:]
    omf_u = nc_uv['u_Obs_Minus_Forecast_unadjusted'][:]
    omf_v = nc_uv['v_Obs_Minus_Forecast_unadjusted'][:]
    #omf_t = nc_t['Obs_Minus_Forecast_unadjusted'][:]
    #omf_q = nc_q['Obs_Minus_Forecast_unadjusted'][:]
    omf_t = nc_t['Obs_Minus_Forecast_adjusted'][:]
    omf_q = nc_q['Obs_Minus_Forecast_adjusted'][:]
    qsges = nc_q['Forecast_Saturation_Spec_Hum'][:]
    if sondesonly:
        insitu_wind = np.logical_or(uv_code == 220, # sondes
                                    uv_code == 232) # drops
        insitu_wind = np.logical_or(insitu_wind, uv_code == 221) # pibals
    elif noair:
        insitu_wind = np.logical_and(uv_code >= 280, uv_code <= 282) #sfc
        # sones, pibals
        insitu_wind = np.logical_or(insitu_wind,\
                      np.logical_or(uv_code == 220, uv_code == 221)) 
        insitu_wind = np.logical_or(insitu_wind, uv_code == 232) # drops
    else:
        insitu_wind = np.logical_and(uv_code >= 280, uv_code <= 282) #sfc
        # sones, pibals
        insitu_wind = np.logical_or(insitu_wind,\
                      np.logical_or(uv_code == 220, uv_code == 221)) 
        #print 'sondes,pibals',np.logical_and(uv_code >= 220, uv_code <= 221).sum()
        # aircraft, drops
        insitu_wind = np.logical_or(insitu_wind,\
                      np.logical_and(uv_code >= 230, uv_code <= 235))
        #print 'aircraft,drops',np.logical_and(uv_code >= 230, uv_code <= 235).sum()
        #print 'drops',(uv_code == 232).sum()
    if sondesonly:
        insitu_temp = np.logical_or(t_code == 120, # sondes
                                    t_code == 132) # drops
        insitu_q = np.logical_or(q_code == 120, # sondes
                                 q_code == 132) # drops
    elif noair:
        insitu_temp = np.logical_or(t_code == 120, # sondes
                                    t_code == 132) # drops
        insitu_q = np.logical_or(q_code == 120, # sondes
                                 q_code == 132) # drops
        insitu_temp = np.logical_or(insitu_temp,np.logical_and(t_code >= 180, t_code <= 182)) #sfc
        insitu_q = np.logical_or(insitu_q,np.logical_and(q_code >= 180, q_code <= 182)) #sfc
    else:
        insitu_temp = np.logical_and(t_code >= 180, t_code <= 182) #sfc
        insitu_temp = np.logical_or(insitu_temp, t_code==120) # sondes
        # aircraft, drops
        insitu_temp = np.logical_or(insitu_temp,\
                      np.logical_and(t_code >= 130, t_code <= 135))
        insitu_q = np.logical_and(q_code >= 180, q_code <= 182) #sfc
        insitu_q = np.logical_or(insitu_q, q_code==120) # sondes
        # aircraft, drops
        insitu_q = np.logical_or(insitu_q,\
                      np.logical_and(q_code >= 130, q_code <= 135))
    # consider this of if used flag is 1, inverse oberr is < 1.e-5 and a valid pressure level is included
    #uv_used = np.logical_and(uv_used == 1, uv_oberrinv > 1.e-5)
    uv_used = uv_used == 1
    uv_used = np.logical_and(uv_used, np.isfinite(uv_press))
    insitu_wind = np.logical_and(insitu_wind,uv_used)
    #t_used = np.logical_and(t_used == 1, t_oberrinv > 1.e-5)
    t_used = t_used == 1
    t_used = np.logical_and(t_used, np.isfinite(t_press))
    insitu_temp = np.logical_and(insitu_temp,t_used)
    #q_used = np.logical_and(q_used == 1, q_oberrinv > 1.e-5)
    q_used = q_used == 1
    q_used = np.logical_and(q_used, np.isfinite(q_press))
    insitu_q = np.logical_and(insitu_q,q_used)
    if hem == 'NH':
        uv_latcond = uv_lat > latbound 
        t_latcond = t_lat > latbound 
        q_latcond = q_lat > latbound 
    elif hem == 'SH':
        uv_latcond = uv_lat < -latbound
        t_latcond = t_lat < -latbound
        q_latcond = q_lat < -latbound
    elif hem == 'TR':
        uv_latcond = np.logical_and(uv_lat <= latbound,uv_lat >= -latbound)
        t_latcond = np.logical_and(t_lat <= latbound,t_lat >= -latbound)
        q_latcond = np.logical_and(q_lat <= latbound,q_lat >= -latbound)
    if hem in ['NH','TR','SH']:
        indxuv = np.logical_and(insitu_wind,uv_latcond)
        indxt = np.logical_and(insitu_temp,t_latcond)
        indxq = np.logical_and(insitu_q,q_latcond)
    else:
        indxuv = insitu_wind; indxt = insitu_temp; indxq = insitu_q
    omf_u = omf_u[indxuv]
    omf_v = omf_v[indxuv]
    omf_t = omf_t[indxt]
    omf_q = 100.*omf_q[indxq]*qsges[indxq] # convert to g/kg?
    press_u = uv_press[indxuv]
    press_t = t_press[indxt]
    press_q = q_press[indxq]
    # compute innovation stats for temperature.
    pindx =  np.digitize(press_t,pbins)-1
    # check on pindx calculation
    #for n in range(len(press_t)):
    #    ip = pindx[n]
    #    p = press_t[n]
    #    if not (p < levs1[ip] and p >= levs2[ip]):
    #        print p, levs2[ip], levs1[ip]
    #        raise IndexError('wind p mismatch')
    rms_temp += np.bincount(pindx,minlength=nlevs,weights=omf_t**2)
    counts, bin_edges = np.histogram(press_t,pbins[::-1])
    omf_tempb[ndate] = np.bincount(pindx,minlength=nlevs,weights=omf_t)/counts[::-1]
    omf_temp[ndate] = np.bincount(pindx,minlength=nlevs,weights=omf_t**2)/counts[::-1]
    temp_obcounts[ndate] = counts[::-1]
    bias_temp += np.bincount(pindx,minlength=nlevs,weights=omf_t)
    count_temp += counts[::-1]
    rms_temp_mean = np.sqrt(np.bincount(pindx,minlength=nlevs,weights=omf_t**2)/counts[::-1])[0:18].mean()
    # compute innovation stats for humidity.
    if sum(indxq) > 0:
        pindx =  np.digitize(press_q,pbins)-1
        # check on pindx calculation
        #for n in range(len(press_q)):
        #    ip = pindx[n]
        #    p = press_q[n]
        #    if not (p < levs1[ip] and p >= levs2[ip]):
        #        print p, levs2[ip], levs1[ip]
        #        raise IndexError('wind p mismatch')
        rms_humid += np.bincount(pindx,minlength=nlevs,weights=omf_q**2)
        bias_humid += np.bincount(pindx,minlength=nlevs,weights=omf_q)
        counts, bin_edges = np.histogram(press_q,pbins[::-1])
        counts = np.where(counts == 0, -1, counts)
        count_humid += counts[::-1]
        rms_humid_mean = np.sqrt(np.bincount(pindx,minlength=nlevs,weights=omf_q**2)/counts[::-1])[0:18].mean()
    else:
        counts_humid += 0
        rms_humid_mean = np.zeros(rms_temp_mean.shape, rms_temp_mean.dtype)
    # compute innovation stats for wind.
    pindx =  np.digitize(press_u,pbins)-1
    # check on pindx calculation
    #for n in range(len(press_u)):
    #    ip = pindx[n]
    #    p = press_u[n]
    #    if not (p < levs1[ip] and p >= levs2[ip]):
    #        print p, levs2[ip], levs1[ip]
    #        raise IndexError('wind p mismatch')
    rms_wind += np.bincount(pindx,minlength=nlevs,weights=np.sqrt(omf_u**2+omf_v**2))
    counts, bin_edges = np.histogram(press_u,pbins[::-1])
    omf_wnd[ndate] = np.bincount(pindx,minlength=nlevs,weights=np.sqrt(omf_u**2+omf_v**2))/counts[::-1]
    wind_obcounts[ndate] = counts[::-1]
    count_wind += counts[::-1]
    rms_wind_mean = (np.bincount(pindx,minlength=nlevs,weights=np.sqrt(omf_u**2+omf_v**2))/counts[::-1])[0:18].mean()
    rms_wind_meantot.append(rms_wind_mean)
    rms_temp_meantot.append(rms_temp_mean)
    rms_humid_meantot.append(rms_humid_mean)
    print(date, rms_wind_mean, rms_temp_mean, rms_humid_mean)
    ndate += 1

ncout.close()
rms_wind = rms_wind/count_wind
rms_temp = np.sqrt(rms_temp/count_temp)
bias_temp = bias_temp/count_temp
rms_humid = np.sqrt(rms_humid/count_humid)
bias_humid = bias_humid/count_humid
rms_wind_mean = np.nanmean(np.array(rms_wind_meantot))
rms_temp_mean = np.nanmean(np.array(rms_temp_meantot))
rms_humid_mean = np.nanmean(np.array(rms_humid_meantot))

fout = open(outfile,'w')
fout.write('# %s %s %s %s-%s\n' % (datapath,runid,hem,date1,date2))
fout.write('# press wind_count wind_rms temp_count temp_rms temp_bias humid_rmsx1000 humid_biasx1000\n')
fout.write('# 1000-0 %10i %7.4f %10i %7.4f %7.4f %10i %7.4f %7.4f\n' % (count_wind.sum(), rms_wind.mean(), count_temp.sum(), rms_temp.mean(), bias_temp.mean(), count_humid.sum(), 1000*rms_humid.mean(), 1000*bias_humid.mean()))
for n,p in enumerate(levs):
    fout.write('%8.2f %10i %7.4f %10i %7.4f %7.4f %10i %7.4f %7.4f\n' % (p,count_wind[n],rms_wind[n],count_temp[n],rms_temp[n],bias_temp[n],count_humid[n],1000*rms_humid[n],1000*bias_humid[n]))
fout.write('#  %7.4f %7.4f %7.4f\n' % (rms_wind_mean,rms_temp_mean,1000.*rms_humid_mean))
fout.close()
