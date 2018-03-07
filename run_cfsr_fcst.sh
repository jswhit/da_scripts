echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=120
export FHOUT=3
export VERBOSE=YES

export charnanal="cfsr"
echo "charnanal = $charnanal"

mkdir -p ${datapath2}/${charnanal}
/bin/cp -f /lustre/f1/unswept/Gary.Bates/cfsr_inits/${yr}/C${RES_CTL}_${analdate}/control/* ${datapath2}/${charnanal}
env

export fg_only=true
csh ${enkfscripts}/run_long_fcst.csh
