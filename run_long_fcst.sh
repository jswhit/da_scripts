echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=120
export FHOUT=3
export VERBOSE=YES

if [ $replay_controlfcst == 'true' ] 
then
   export charnanal="control2"
elif [ $controlfcst == 'false' ] 
then
   export charnanal="ensmean"
   unset skip_calc_increment
   unset skip_global_cycle
else
   export charnanal="control"
fi
echo "charnanal = $charnanal"

#env
if [ $run_long_fcst_cfsr == "true" ]; then
   export submit_hpss=false
else
   export submit_hpss=true
fi
mkdir -p ${datapath2}/longfcst/${charnanal}
csh ${enkfscripts}/run_long_fcst.csh &> ${datapath2}/longfcst/${charnanal}/longfcst.out 

if [ $run_long_fcst_cfsr == "true" ]; then
   echo "$analdate run high-res control long fcst from CFSR initial conditions `date`"
   
   export charnanal="cfsr"
   echo "charnanal = $charnanal"
   mkdir -p ${datapath2}/${charnanal}
   /bin/cp -f /lustre/f1/unswept/Gary.Bates/cfsr_inits/${yr}/C${RES_CTL}_${analdate}/control/* ${datapath2}/${charnanal}
   
   #env
   export fg_only=true
   export submit_hpss=true
   mkdir -p ${datapath2}/longfcst/${charnanal}
   csh ${enkfscripts}/run_long_fcst.csh &> ${datapath2}/longfcst/${charnanal}/longfcst.out 
fi
