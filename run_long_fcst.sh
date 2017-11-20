echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=120
export FHOUT=6
export quilting=.false.
csh ${enkfscripts}/run_long_fcst.csh
