#!/bin/sh

cd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."

for nhr_anal in $iaufhrs2; do

charfhr="fhr"`printf %02i $nhr_anal`
charfhr2=`printf %02i $nhr_anal`

if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ] && [ ! -s ${datapath}/${analdate}/sanl_${analdate}_${charfhr}_ensmean ]); then
   /bin/rm -f sanl_${analdate}_${charfhr}_ensmean
   export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals}"
   ${enkfscripts}/runmpi
fi

done
ls -l ${datapath2}/sanl_${analdate}*ensmean
