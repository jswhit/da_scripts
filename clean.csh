echo "clean up files `date`"
cd $datapath2

# move every member files to a temp dir.
/bin/rm -rf fgens fgens2
mkdir fgens
mkdir fgens2
if ($replay_controlfcst == 'true') then
   set charnanal='control2'
else
   set charnanal='control'
endif
/bin/rm -f mem*/*nc mem*/*txt mem*/*grb mem*/*dat mem*/co2*
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/co2*
/bin/mv -f mem* fgens
/bin/mv -f sfg*mem* fgens2
/bin/mv -f bfg*mem* fgens2
if ($replay_controlfcst == 'true') then
/bin/cp -f sfg*control2 bfg*control2 fgens2
else
/bin/cp -f sfg*control bfg*control fgens2
endif

#mkdir analens
#/bin/mv -f sanl_*mem* analens # save analysis ensemble
#echo "files moved to analens `date`"
/bin/rm -f sanl_*mem* # don't save analysis ensemble

/bin/rm -f sanl*ensmean sanl*ensmean*orig
/bin/rm -f sanl*control 
/bin/rm -f s*ensmean*nc4 # just save spread netcdf files.
/bin/rm -f fgens2/*fhr00* fgens2/*orig
echo "files moved to fgens, fgens2 `date`"
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
