export NODES=1
source $MODULESHOME/init/sh
if [ $machine == "gaea" ]; then
   module load hsi
else
   module load hpss
fi
env
hsi ls -l $hsidir
hsi mkdir ${hsidir}/
cd ${DATOUT}
cd ..
htar -cvf ${hsidir}/${analdate}_longfcst.tar longfcst
hsi ls -l ${hsidir}/${analdate}_longfcst.tar
if [  $? -eq 0 ]; then
   # delete 6 tile files on disk (keep latlon files)
  /bin/rm -f ${DATOUT}/*/fv3_historyp*tile*.nc
fi
