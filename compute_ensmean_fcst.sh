#!/bin/sh

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

if [ $nanals2 -gt 0 ]; then
fh=`expr ${FHMAX_LONGER} - ${ANALINC}`
while [ $fh -le $FHMAX_LONGER ]; do
  charfhr="fhr`printf %02i $fh`"

  if [ -s ${datapath2}/sfg2_${analdate}_${charfhr}_mem001 ]; then
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg2_${analdate}_${charfhr}_ensmean ]); then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals2}"
      /bin/rm -f ${datapath2}/bfg2_${analdate}_${charfhr}_ensmean
      export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg2_${analdate}_${charfhr}_ensmean bfg2_${analdate}_${charfhr} ${nanals2}"
      ${enkfscripts}/runmpi
      if [ ! -s ${datapath}/${analdate}/bfg2_${analdate}_${charfhr}_ensmean ]; then
         echo "getsfcensmeanp.x failed..."
         exit 1
      fi
  fi
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]); then
      /bin/rm -f ${datapath2}/sfg2_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals2} sfg2_${analdate}_${charfhr}_enssprd"
      ANALINC2=`expr $ANALINC + $ANALINC`
      if [ $fh -eq $ANALINC2 ]; then # just save spread at middle of window
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals2} sfg2_${analdate}_${charfhr}_enssprd"
      else
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg2_${analdate}_${charfhr}_ensmean sfg2_${analdate}_${charfhr} ${nanals2}"
      fi
      ${enkfscripts}/runmpi
      if [ ! -s ${datapath}/${analdate}/sfg2_${analdate}_${charfhr}_ensmean ]; then
         echo "getsigensmeanp_smooth.x failed..."
         exit 1
      fi
  fi
  fi

  fh=$((fh+FHOUT))

done
fi

echo "all done `date`"
