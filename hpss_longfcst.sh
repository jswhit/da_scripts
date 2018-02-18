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
