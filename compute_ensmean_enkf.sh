#!/bin/sh

cd ${datapath2}

fhrs=`echo $enkfanalfhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."

for nhr_anal in $fhrs; do

charfhr="fhr"`printf %02i $nhr_anal`

if [ $write_ensmean != ".true." ]; then
if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ] && [ ! -s ${datapath}/${analdate}/sanl_${analdate}_${charfhr}_ensmean ]); then
   /bin/rm -f sanl_${analdate}_${charfhr}_ensmean
   export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals}"
   ${enkfscripts}/runmpi
fi
fi

# copy analysis files to be background files for next analysis time
# for next anal time, fhr=3,4 are analyses, fhr=5 is a fhr=0 (1 timestep) forecast,
# fhr=6,7 are fhr=1,2 hr forecasts, and fhr=8,9 are missing.
if [ $nhr_anal -lt 6 ]; then # skip analysis time, use one timestep forecasts
   nhr_out=`expr $nhr_anal - 1`
   charfhr_out="fhr"`printf %02i $nhr_out`
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal="mem`printf %03i $nanal`"
      /bin/cp -f ${datapath2}/sanl_${analdate}_${charfhr}_${charnanal} ${datapath}/${analdatep1}/sfg_${analdatep1}_${charfhr_out}_${charnanal}
      # also copy bfg files
      /bin/cp -f ${datapath2}/bfg_${analdate}_${charfhr}_${charnanal} ${datapath}/${analdatep1}/bfg_${analdatep1}_${charfhr_out}_${charnanal}
      nanal=$((nanal+1))
   done
fi

done
ls -l ${datapath2}/sanl_${analdate}*ensmean
