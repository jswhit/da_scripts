echo "clean up files `date`"
cd $datapath2

# move every member files to a temp dir.
/bin/rm -rf fgens fgens2
mkdir fgens
mkdir fgens2
mkdir analens
if ($replay_controlfcst == 'true') then
   set charnanal='control2'
else
   set charnanal='control'
endif
/bin/rm -f mem*/*nc mem*/*txt mem*/*grb mem*/*dat mem*/co2*
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/co2*
# every 06z save nanals_replay member + ens mean restarts.
if ($nanals_replay > 0 && $ensmean_restart == 'true' && $hr == '06') then
    /bin/rm -rf restarts
    mkdir restarts
    /bin/cp -R ${charnanal} restarts
    mkdir restarts/ensmean
    /bin/mv -f ensmean/INPUT restarts/ensmean
    set nanal=1
    while ($nanal <= $nanals_replay) 
       set charmem="mem`printf %03i $nanal`"
       /bin/cp -R ${charmem} restarts
       /bin/rm -f restarts/${charmem}/stoch_ini
       /bin/rm -f restarts/*/PET* restarts/*/log*
       @ nanal = $nanal + 1
    end
endif
/bin/mv -f mem* fgens
/bin/mv -f sfg*mem* fgens2
/bin/mv -f bfg*mem* fgens2
if ($replay_controlfcst == 'true') then
/bin/cp -f sfg*control2 bfg*control2 fgens2
else
/bin/cp -f sfg*control bfg*control fgens2
endif
/bin/mv -f sanl_*mem*grib analens # save for replay
if ($nanals_replay > 0) then
   mkdir analens${nanals_replay}
   /bin/mv -f sanl${nanals_replay}*grib analens${nanals_replay}
   /bin/cp -f sanl*ensmean.grib analens${nanals_replay}
endif
/bin/rm -f sanl*ensmean sanl*ensmean*orig
/bin/rm -f sanl*control 
/bin/rm -f s*ensmean*nc4 # just save spread netcdf files.
/bin/rm -f fgens2/*fhr00* fgens2/*orig
# delete sfg ensmean and control files if grib versions exist
if ($replay_controlfcst == 'true') then
 set charnanal='control2'
else
 set charnanal='control'
endif
foreach charfhr (00 03 06 09)
   if ( -s ${datapath2}/sfg_${analdate}_fhr${charfhr}_${charnanal}.grib ) then
     /bin/rm -f ${datapath2}/sfg_${analdate}_fhr${charfhr}_${charnanal}
   endif
end
set charnanal='ensmean'
foreach charfhr (00 03 06 09)
   if ( -s ${datapath2}/sfg_${analdate}_fhr${charfhr}_${charnanal}.grib ) then
     /bin/rm -f ${datapath2}/sfg_${analdate}_fhr${charfhr}_${charnanal}
   endif
end
echo "files moved to analens, fgens, fgens2 `date`"
if ( ! $?NOSAT ) then
# only save control and spread diag files.
/bin/rm -rf diag*ensmean.nc4
# only save conventional diag files
#mkdir diagsavdir
#/bin/mv -f diag*conv*control*nc4 diag*conv*spread*nc4 diagsavdir
#/bin/rm -f diag*control*nc4 diag*spread*nc4
#/bin/rm -f diagsavdir/diag*conv_gps*
#/bin/mv -f diagsavdir/diag*nc4 .
#/bin/rm -rf diagsavdir
endif

/bin/rm -f hostfile*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -f *lores *mem*orig
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
/bin/rm -rf hybridtmp* gsitmp* gfstmp* nodefile* machinefile*
/bin/rm -f */PET*
#/bin/rm -f ensmean/*tile*nc
echo "unwanted files removed `date`"
wait
