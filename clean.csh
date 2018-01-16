echo "clean up files `date`"
cd $datapath2

# move every member files to a temp dir.
/bin/rm -rf fgens fgens2
mkdir fgens
mkdir fgens2
mkdir analens
/bin/rm -f mem*/*nc mem*/*txt mem*/*grb mem*/*dat 
/bin/mv -f mem* fgens
/bin/mv -f sfg*mem* fgens2
/bin/mv -f bfg*mem* fgens2
if ($replay_controlfcst == 'true') then
/bin/cp -f sfg*control2 bfg*control2 fgens2
else
/bin/cp -f sfg*control bfg*control fgens2
endif
/bin/mv -f sanl*grib analens # save for replay
/bin/rm -f sanl*ensmean sanl*ensmean.orig
/bin/rm -f sanl*control
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
echo "unwanted files removed `date`"
wait
