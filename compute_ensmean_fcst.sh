#!/bin/sh

num_jobs=8
num_nodes=`expr $NODES \/ $num_jobs`
export mpitaskspernode=`python -c "from __future__ import print_function; import math; print(int(math.ceil(float(${nanals})/float(${num_nodes}))))"`
if [ $mpitaskspernode -lt 1 ]; then
  export mpitaskspernode 1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals

export OMP_STACKSIZE=1024M

cd ${datapath2}

fh=${FHMIN}
njob=0
while [ $fh -le $FHMAX ]; do

  charfhr="fhr`printf %02i $fh`"

  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]); then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
      export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      ${enkfscripts}/runmpi  &
      njob=$((njob+1))
      #if [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]; then
      #   echo "getsfcensmeanp.x failed..."
      #   exit 1
      #fi
  fi
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]); then
      /bin/rm -f ${datapath2}/sfg_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      if [ $fh -eq $ANALINC ]; then # just save spread at middle of window
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      else
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals}"
      fi
      ${enkfscripts}/runmpi  &
      njob=$((njob+1))
      #if [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]; then
      #   echo "getsigensmeanp_smooth.x failed..."
      #   exit 1
      #fi
  fi

  if [ $njob -eq $num_jobs ]; then
     wait
     njob=0
  fi
  fh=$((fh+FHOUT))

done

fh=3
charfhr="fhr`printf %02i $fh`"
fhend=`expr $FHMAX_LONGER + 3`
njob=0
while [ $fh -le $fhend ]; do

  #if [ $fhend -eq 12 ] && [ $fh -ne 10 ] && [ $fh -ne 11 ]; then # skip forecast hours 10 and 11 (just keep last one, 12)

  if [ -s ${datapath2}/bfg2_${analdate}_${charfhr}_mem001 ]; then
     if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg2_${analdate}_${charfhr}_ensmean ]); then
         echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals}"
         /bin/rm -f ${datapath2}/bfg2_${analdate}_${charfhr}_ensmean
         export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals}"
         ${enkfscripts}/runmpi &
         njob=$((njob+1))
         #if [ ! -s ${datapath}/${analdate}/bfg2_${analdate}_${charfhr}_ensmean ]; then
         #   echo "getsfcensmeanp.x failed..."
         #   exit 1
         #fi
     fi
  fi
  if [ -s ${datapath2}/sfg2_${analdate}_${charfhr}_mem001 ]; then
     if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]); then
         /bin/rm -f ${datapath2}/sfg2_${analdate}_${charfhr}_ensmean
         if [ $fh -eq 6 ]; then # just save spread at middle of window
            export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
         else
            export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals}"
         fi
         ${enkfscripts}/runmpi &
         njob=$((njob+1))
         #if [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]; then
         #   echo "getsigensmeanp_smooth.x failed..."
         #   exit 1
         #fi
     fi
  fi
  if [ $njob -eq $num_jobs ]; then
     wait
     njob=0
  fi

  #fi # skip fhrs 10 and 11 if fhend=12

  fh=$((fh+FHOUT))
  charfhr="fhr`printf %02i $fh`"

done
wait

echo "all done `date`"
