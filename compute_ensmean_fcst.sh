#!/bin/sh

source $MODULESHOME/init/sh
if [ $machine == 'gaea' ]; then
   nces=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/nces
else
   module load nco
   nces=`which nces`
fi
module list
export OMP_STACKSIZE=1024M

cd ${datapath2}

fh=${FHMIN}
while [ $fh -le $FHMAX ]; do

  charfhr="fhr`printf %02i $fh`"

  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]); then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
      export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      ${enkfscripts}/runmpi
      if [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]; then
         echo "getsfcensmeanp.x failed..."
         exit 1
      fi
  fi
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]); then
      /bin/rm -f ${datapath2}/sfg_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      if [ $fh -eq $ANALINC ]; then # just save spread at middle of window
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
      else
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals}"
      fi
      ${enkfscripts}/runmpi
      if [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]; then
         echo "getsigensmeanp_smooth.x failed..."
         exit 1
      fi
  fi

  fh=$((fh+FHOUT))

done

fh=3
charfhr="fhr`printf %02i $fh`"
fhend=`expr $FHMAX_LONGER + 3`
while [ $fh -le $fhend9 ]; do

  if [ -s ${datapath2}/bfg2_${analdate}_${charfhr}_mem001 ]; then
     if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]); then
         echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals}"
         /bin/rm -f ${datapath2}/bfg2_${analdate}_${charfhr}_ensmean
         export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals}"
         ${enkfscripts}/runmpi
         if [ ! -s ${datapath}/${analdate}/bfg2_${analdate}_${charfhr}_ensmean ]; then
            echo "getsfcensmeanp.x failed..."
            exit 1
         fi
     fi
  fi
  if [ -s ${datapath2}/sfg2_${analdate}_${charfhr}_mem001 ]; then
     if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]); then
         /bin/rm -f ${datapath2}/sfg2_${analdate}_${charfhr}_ensmean
         echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals} sfg2_${analdate}_${charfhr}_enssprd"
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals} sfg2_${analdate}_${charfhr}_enssprd"
         ${enkfscripts}/runmpi
         if [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]; then
            echo "getsigensmeanp_smooth.x failed..."
            exit 1
         fi
     fi
  fi

  fh=$((fh+FHOUT))
  charfhr="fhr`printf %02i $fh`"

done

echo "all done `date`"
