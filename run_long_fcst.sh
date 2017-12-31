echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=120
export FHOUT=3
csh ${enkfscripts}/run_long_fcst.csh
