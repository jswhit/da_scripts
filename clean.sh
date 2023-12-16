echo "clean up files `date`"
cd $datapath2
charnanal='control'
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt* ${charnanal}/*f77 ${charnanal}/*BIN ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/MEMO ${charnanal}/*co2*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -rf *tmp*
#/bin/rm -rf ${charnanal}
/bin/rm -f ${charnanal}/PET* ${charnanal}/log*
YYYYMMDD=`echo $analdate | cut -c1-8`
HH=`echo $analdate | cut -c9-10`
if [ $use_s3obs == "true" ]; then
   /bin/rm -rf ${obs_datapath}/gdas.${YYYYMMDD}/${HH}
fi
if [ $HH -ne '06' ]; then # only save restarts at 6z
   /bin/rm -rf control
fi

echo "unwanted files removed `date`"
