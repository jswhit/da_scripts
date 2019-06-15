#!/bin/sh
# run ensemble first guess.
# first, clean up old first guesses.
if [ $cleanup_fg == 'true' ];  then
echo "deleting existing files..."
nanal=1
while [ $nanal -le $nanals ]; do
    charnanal="mem`printf %03i $nanal`"
    /bin/rm -f ${datapath}/${analdatep1}/sfg_${analdatep1}*${charnanal}
    /bin/rm -f ${datapath}/${analdatep1}/bfg_${analdatep1}*${charnanal} 
    nanal=$((nanal+1))
done
fi
mkdir -p ${datapath}/${analdatep1}

export niter=1
alldone='no'
echo "${analdate} compute first guesses `date`"
while [ $alldone == 'no' ] && [ $niter -le $nitermax ]; do
    if [ $niter -eq 1 ]; then
    ${enkfscripts}/${fg_gfs} > ${current_logdir}/run_fg.iter${niter}.out 2>&1
    exitstat=$?
    else
    ${enkfscripts}/${fg_gfs} > ${current_logdir}/run_fg.iter${niter}.out 2>&1
    exitstat=$?
    fi
    if [ $exitstat -eq 0 ]; then
       alldone='yes'
    else
       echo "some files missing, try again .."
       niter=$((niter+1))
       export niter=$niter
    fi
done

if [ $alldone == 'no' ]; then
    echo "Tried ${nitermax} times to run ens first-guesses and failed: ${analdate}"
    echo "no" > ${current_logdir}/run_fg_ens.log
else
    echo "yes" > ${current_logdir}/run_fg_ens.log
fi
