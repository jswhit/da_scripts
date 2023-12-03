# need envars:  machine, analdate, datapath2, hsidir, save_hpss

exitstat=0
if [ $machine == "gaea" ]; then
   htar=/sw/rdtn/hpss/default/bin/htar
   hsi=/sw/rdtn/hpss/default/bin/hsi
else
   source $MODULESHOME/init/sh
   module load hpss
   hsi=`which hsi`
   htar=`which htar`
fi
$hsi ls -l $hsidir
$hsi mkdir ${hsidir}/
cd ${datapath}

$htar -cvf ${hsidir}/${analdate}.tar ${analdate}/gdas* ${analdate}/*control* ${analdate}/logs
$hsi ls -l ${hsidir}/${analdate}.tar
exitstat=$?
if [  $exitstat -ne 0 ]; then
   echo "hsi subset failed ${analdate} with exit status $exitstat..."
   exit 1
fi

exit $exitstat
