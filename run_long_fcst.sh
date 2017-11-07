echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=240
csh ${enkfscripts}/run_long_fcst.csh  >> ${current_logdir}/run_long_fcst.out 2>&1
longfcst_done=`cat ${current_logdir}/run_long_fcst.log`
if [ "$longfcst_done" == 'yes' ]; then
  echo "$analdate high-res control long fcst completed successfully `date`"
else
  echo "$analdate high-res control long fcst did not complete successfully, exiting `date`"
  exit 1
fi
