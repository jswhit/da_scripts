echo "clean up files `date`"
cd $datapath2

# move every member files to a temp dir.
/bin/rm -rf fgens fgens2
mkdir fgens
mkdir fgens2
charnanal='control'
/bin/rm -f mem*/*nc mem*/*txt mem*/*grb mem*/*dat mem*/co2*
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/co2*
/bin/mv -f mem* fgens
/bin/mv -f sfg*mem* fgens2
/bin/mv -f bfg*mem* fgens2
/bin/cp -f sfg*ensmean fgens2
/bin/cp -f sfg*control bfg*control fgens2

#mkdir analens
#/bin/mv -f sanl_*mem* analens # save analysis ensemble
#echo "files moved to analens `date`"
/bin/rm -f sanl_*mem* # don't save analysis ensemble
/bin/rm -f fgens2/*fhr00* fgens2/*orig
echo "files moved to fgens, fgens2 `date`"
#if [ -z $NOSAT ]; then
# only save control and spread diag files.
#/bin/rm -rf diag*ensmean.nc4
# only save conventional diag files
#mkdir diagsavdir
#/bin/mv -f diag*conv*control*nc4 diag*conv*spread*nc4 diagsavdir
#/bin/rm -f diag*control*nc4 diag*spread*nc4
#/bin/rm -f diagsavdir/diag*conv_gps*
#/bin/mv -f diagsavdir/diag*nc4 .
#/bin/rm -rf diagsavdir
#fi
# delete these to save space
#/bin/rm -f diag*cris* diag*airs* diag*iasi*

/bin/rm -f hostfile*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -f *lores *mem*orig
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
/bin/rm -rf *tmp* nodefile* machinefile*
/bin/rm -rf hybridtmp*
echo "save_hpss_subset $save_hpss_subset save_hpss_full $save_hpss_full"
if [ $save_hpss_subset == "false" ] && [ $save_hpss_full == "false" ]; then
  /bin/rm -rf fgens fgens2
  /bin/rm -f diag*cris* diag*airs* diag*iasi*
  /bin/rm -f *chgres
  /bin/rm -rf ensmean
  #if [ $hr != '00' ]; then
  #    /bin/rm -rf control
  #fi
  # save backup of next analysis time once per day
  # so analysis can be restarted
  hr=`echo $analdatep1 | cut -c9-10`
  if [ $machine == 'orion' ] || [ $machine == 'hercules' ]; then
     if [ $hr == '00' ]; then
        pushd $datapath
        tar -cvf ${analdatep1}_restart.tar ${analdatep1}
        popd
     fi
  fi
fi
echo "unwanted files removed `date`"
wait
