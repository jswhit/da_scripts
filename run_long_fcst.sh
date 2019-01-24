echo "$analdate run high-res control long fcst `date`"
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

export control_proc=$control_proc_noquilt

env
csh ${enkfscripts}/run_long_fcst.csh
