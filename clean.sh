echo "clean up files `date`"
cd $datapath2
charnanal='control'
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/co2*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -rf *tmp*
#/bin/rm -rf ${charnanal}
/bin/rm -f ${charnanal}/PET* ${charnanal}/log*
if [ $use_s3obs == "true" ]; then
   YYYYMMDD=`echo $analdate | cut -c1-8`
   HH=`echo $analdate | cut -c9-10`
   /bin/rm -rf ${obs_datapath}/gdas.${YYYYMMDD}/${HH}
fi
echo "unwanted files removed `date`"
