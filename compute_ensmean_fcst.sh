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

fh=3
charfhr="fhr`printf %02i $fh`"
while [ $fh -le 9 ] && [ -s ${datapath2}/sfg_${analdate}_${charfhr}_mem001 ]; do

  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]); then
      if [ $FHMAX -eq 4 ] && [ $fh -gt 7 ] && [ $cold_start != "true" ]; then
         # symlink last two forecast times (only needed to trick GSI into believing window is symmetric)
         /bin/ln -fs ${datapath}/${analdate}/bfg_${analdatep1}_fhr07_ensmean ${datapath}/${analdate}/bfg_${analdatep1}_${charfhr}_ensmean
      else
         /bin/rm -f  ${datapath}/${analdate}/bfg_${analdatep1}_${charfhr}_ensmean
         echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
         /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
         export PGM="${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
         ${enkfscripts}/runmpi
         if [ ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean ]; then
            echo "getsfcensmeanp.x failed..."
            exit 1
         fi
      fi
  fi
  if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ]  && [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]); then
      if [ $FHMAX -eq 4 ] && [ $fh -gt 7 ] && [ $cold_start != "true" ]; then
         # symlink last two forecast times (only needed to trick GSI into believing window is symmetric)
         /bin/ln -fs ${datapath}/${analdate}/sfg_${analdatep1}_fhr07_ensmean ${datapath}/${analdate}/sfg_${analdatep1}_${charfhr}_ensmean
         /bin/ln -fs ${datapath}/${analdate}/sfg_${analdatep1}_fhr07_enssprd ${datapath}/${analdate}/sfg_${analdatep1}_${charfhr}_enssprd
      else
         /bin/rm -f  ${datapath}/${analdate}/sfg_${analdatep1}_${charfhr}_ensmean
         /bin/rm -f  ${datapath}/${analdate}/sfg_${analdatep1}_${charfhr}_enssprd
         echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
         export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} sfg_${analdate}_${charfhr}_enssprd"
         ${enkfscripts}/runmpi
         if [ ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean ]; then
            echo "getsigensmeanp_smooth.x failed..."
            exit 1
         fi
      fi
  fi

  fh=$((fh+FHOUT))
  charfhr="fhr`printf %02i $fh`"

done

fh=3
charfhr="fhr`printf %02i $fh`"
while [ $fh -le 9 ] && [ -s ${datapath2}/sfg2_${analdate}_${charfhr}_mem001 ]; do

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

  fh=$((fh+FHOUT))
  charfhr="fhr`printf %02i $fh`"

done

echo "all done `date`"
