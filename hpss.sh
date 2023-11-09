# need envars:  machine, analdate, datapath2, hsidir, save_hpss

exitstat=0
source $MODULESHOME/init/sh
if [ $machine == "gaea" ]; then
   module load hsi
else
   module load hpss
fi
hsi ls -l $hsidir
hsi mkdir ${hsidir}/
cd ${datapath2}

htar -cvf ${hsidir}/${analdate}.tar ${analdate}/gdas* ${analdate}/*control* ${analdate}/logs
hsi ls -l ${hsidir}/${analdate}.tar
exitstat=$?
if [  $exitstat -ne 0 ]; then
   echo "hsi subset failed ${analdate} with exit status $exitstat..."
   exit 1
fi

exit $exitstat
