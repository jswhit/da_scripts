#!/bin/sh

source $MODULESHOME/init/sh
if [ $machine == 'wcoss' ]; then
   module load nco-gnu-sandybridge
   nces=`which nces`
elif [ $machine == 'gaea' ]; then
   nces=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/nces
elif [ $machine == 'theia' ]; then
   module load nco/4.7.0
   nces=`which nces`
else
   module load nco
   nces=`which nces`
fi
module list
export HOSTFILE=${datapath2}/machinesx
export OMP_STACKSIZE=2048M

cd ${datapath2}

fh=${FHMIN}
while [ $fh -le $FHMAX ]; do

  charfhr="fhr`printf %02i $fh`"

  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]); then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
      export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      ${enkfscripts}/runmpi
  fi
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]); then
      /bin/rm -f ${datapath2}/sfg_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      #if [ $fh -eq $ANALINC ]; then
      export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      ${enkfscripts}/runmpi
      #else
      #export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals}"
      #$${enkfscripts}/runmpi
      #fi
  fi

  fh=$((fh+FHOUT))

done

# now compute ensemble mean restart files (only at 00UTC).
if [ $ensmean_restart == 'true' ] && [ $fg_only == 'false' ] && [ $hr == '06' ]; then
if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath2}/ensmean/INPUT/fv_core.res.tile1.nc ]); then
   echo "compute ensemble mean restart files `date`"
   export nprocs=1
   export mpitaskspernode=1
   export OMP_NUM_THREADS=$corespernode
   pathout=${datapath2}/ensmean/INPUT
   mkdir -p $pathout
   ncount=1
   tiles="tile1 tile2 tile3 tile4 tile5 tile6"
   for tile in $tiles; do
      files="fv_core.res.${tile}.nc fv_tracer.res.${tile}.nc fv_srf_wnd.res.${tile}.nc sfc_data.${tile}.nc phy_data.${tile}.nc"
      for file in $files; do
         export PGM="${nces} -O `ls -1 ${datapath2}/mem*/INPUT/${filename}` ${pathout}/${filename}"
         if [ -z $SLURM_JOB_ID ] && [ $machine == 'theia' ]; then
            host=`head -$ncount $NODEFILE | tail -1`
            export HOSTFILE=${datapath2}/hostfile_nces_${ncount}
            echo $host > $HOSTFILE
         fi
         echo "computing ens mean for $filename"
         #${enkfscripts}/runmpi &
         $PGM &
         if [ $ncount == $NODES ]; then
            echo "waiting for backgrounded jobs to finish..."
            wait
            ncount=1
         else
            ncount=$((ncount+1))
         fi
      done
   done
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   /bin/cp -f ${datapath2}/mem001/INPUT/fv_core.res.nc ${pathout}
   echo "done computing ensemble mean restart files `date`"
fi
fi

if [ $controlfcst == 'false' ] && [ $cleanup_ensmean == 'true' ] && [ ! -z $copy_history_files ];  then
   echo "compute ensemble mean history files `date`"
   export nprocs=1
   export mpitaskspernode=1
   export OMP_NUM_THREADS=$corespernode
   pathout=${datapath2}/ensmean
   mkdir -p $pathout
   ncount=1
   tiles="tile1 tile2 tile3 tile4 tile5 tile6"
   for tile in $tiles; do
      filename="fv3_historyp.${tile}.nc"
      export PGM="${nces} -4 -L 5 -O `ls -1 ${datapath2}/mem*/${filename}` ${pathout}/${filename}"
      if [ $machine == 'theia' ]; then
         host=`head -$ncount $NODEFILE | tail -1`
         export HOSTFILE=${datapath2}/hostfile_nces_${ncount}
         echo $host > $HOSTFILE
      fi
      echo "computing ens mean for $filename"
      #${enkfscripts}/runmpi &
      $PGM &
      if [ $ncount == $NODES ]; then
         echo "waiting for backgrounded jobs to finish..."
         wait
         ncount=1
      else
         ncount=$((ncount+1))
      fi
   done
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   echo "done computing ensemble mean history files `date`"
   # interpolate to 1x1 grid
   cd ${enkfscripts}
   $python ncinterp.py ${datapath2}/ensmean ${datapath2}/fv3ensmean_historyp_${analdatem1}_latlon.nc $RES $analdatem1
fi

echo "all done `date`"
