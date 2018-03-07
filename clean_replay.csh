echo "clean up files `date`"
cd $datapath2

set charnanal='control2'
/bin/rm -rf ${charnanal}/INPUT
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

/bin/rm -f hostfile*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
/bin/rm -rf hybridtmp* gsitmp* gfstmp* nodefile* machinefile*
echo "unwanted files removed `date`"
wait
