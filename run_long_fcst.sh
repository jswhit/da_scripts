echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=240
export FHOUT=3
export quilting=.true.
csh ${enkfscripts}/run_long_fcst.csh
