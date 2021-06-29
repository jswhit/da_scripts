#!/bin/sh

cd ${datapath2}

fhrs=`echo $enkfanalfhrs | sed 's/,/ /g'`

#echo "copy analysis files to be background files for the next analysis time...."

for nhr_anal in $fhrs; do

charfhr="fhr"`printf %02i $nhr_anal`

# copy analysis files to be background files for next analysis time
# for next anal time, fhr=3,4 are analyses, fhr=5 is a fhr=0 (1 timestep) forecast,
# fhr=6,7 are fhr=1,2 hr forecasts, and fhr=8,9 are missing.
if [ $nhr_anal -lt 6 ]; then # skip analysis time, use one timestep forecasts
   nhr_out=`expr $nhr_anal - 1`
   charfhr_out="fhr"`printf %02i $nhr_out`
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal="mem`printf %03i $nanal`"
      /bin/mv -f ${datapath2}/sanl_${analdate}_${charfhr}_${charnanal} ${datapath}/${analdatep1}/sfg_${analdatep1}_${charfhr_out}_${charnanal}
      # also copy bfg files
      /bin/mv -f ${datapath2}/bfg_${analdate}_${charfhr}_${charnanal} ${datapath}/${analdatep1}/bfg_${analdatep1}_${charfhr_out}_${charnanal}
      nanal=$((nanal+1))
   done
fi

done
