echo "clean up files `date`"
cd $datapath2
charnanal='control'
/bin/rm -f ${charnanal}/*nc ${charnanal}/*txt ${charnanal}/*grb ${charnanal}/*dat ${charnanal}/co2*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -rf *tmp*
#/bin/rm -rf ${charnanal}
/bin/rm -f ${charnanal}/PET* ${charnanal}/log*
echo "unwanted files removed `date`"
