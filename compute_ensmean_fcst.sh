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

fh=${FHMAX}
charfhr="fhr`printf %02i $fh`"
if [ $ANALINC -eq 1 ]; then
  analdate_save=`$incdate $analdate 2`
  mkdir -p ${datapath}/${analdate_save}
  nanals2=80
fi
ANALINC2=`expr $FHMAX_LONGER - 3`
while [ $fh -le $FHMAX_LONGER ] && [ -s ${datapath2}/sfg2_${analdate}_${charfhr}_mem001 ]; do

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

  if [ $ANALINC -eq 1 ]; then
    fh2=$((fh+2))
    charfhr2="fhr`printf %02i $fh2`"
    /bin/mv -f ${datapath2}/sfg2_${analdate}_${charfhr}_ensmean ${datapath}/${analdate_save}/sfg_${analdate_save}_${charfhr2}_ensmean
    /bin/mv -f ${datapath2}/bfg2_${analdate}_${charfhr}_ensmean ${datapath}/${analdate_save}/bfg_${analdate_save}_${charfhr2}_ensmean
    /bin/mv -f ${datapath2}/sfg2_${analdate}_${charfhr}_enssprd ${datapath}/${analdate_save}/sfg_${analdate_save}_${charfhr2}_enssprd
  fi
  fh=$((fh+FHOUT))
  charfhr="fhr`printf %02i $fh`"

done

echo "all done `date`"
