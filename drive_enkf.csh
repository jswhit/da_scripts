# setup node parameters used in compute_ensmean_enkf.csh
setenv mpitaskspernode `python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if ($mpitaskspernode < 1) setenv mpitaskspernode 1
setenv OMP_NUM_THREADS `expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
setenv nprocs $nanals
if ($machine == 'theia') then
    # HOSTFILE is machinefile to use for programs that require $nanals tasks.
    # if enough cores available, just one core on each node.
    # NODEFILE is machinefile containing one entry per node.
    setenv HOSTFILE $datapath2/machinesx1
    setenv NODEFILE $datapath2/nodefile1
    cat $hostfilein | uniq > $NODEFILE
    if ($NODES >= $nanals) then
      ln -fs $NODEFILE $HOSTFILE
    else
      # otherwise, leave as many cores empty as possible
      awk "NR%${OMP_NUM_THREADS} == 1" ${hostfilein} >&! $HOSTFILE
    endif
endif

# run gsi observer with ens mean fcst background, saving jacobian.
# generated diag files used by EnKF
setenv charnanal 'ensmean' 
setenv charnanal2 'ensmean'
setenv lobsdiag_forenkf '.true.'
setenv skipcat "false"
echo "$analdate run gsi observer on ${charnanal} `date`"
csh ${enkfscripts}/run_gsiobserver.csh >&! ${current_logdir}/run_gsi_observer.out 
# once observer has completed, check log files.
set hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
if ($hybrid_done == 'yes') then
  echo "$analdate gsi observer completed successfully `date`"
else
  echo "$analdate gsi observer did not complete successfully, exiting `date`"
  exit 1
endif

# run enkf analysis.
echo "$analdate run enkf `date`"
if ($skipcat == "true") then
  # read un-concatenated pe files (set npefiles to number of mpi tasks used by gsi observer)
  setenv npefiles `expr $cores \/ $gsi_control_threads`
else
  setenv npefiles 0
endif
csh ${enkfscripts}/runenkf.csh  >>& ${current_logdir}/run_enkf.out  
# once enkf has completed, check log files.
set enkf_done=`cat ${current_logdir}/run_enkf.log`
if ($enkf_done == 'yes') then
  echo "$analdate enkf analysis completed successfully `date`"
else
  echo "$analdate enkf analysis did not complete successfully, exiting `date`"
  exit 1
endif

# for passive (replay) cycling of control forecast, optionally run GSI observer
# on control forecast background (diag files saved with 'control2' suffix)
if ($controlfcst == 'true' && $replay_controlfcst == 'true' && $replay_run_observer == "true") then
   setenv charnanal 'control2'
   setenv charnanal2 'control2'
   setenv lobsdiag_forenkf '.false.'
   setenv skipcat "false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   csh ${enkfscripts}/run_gsiobserver.csh >&! ${current_logdir}/run_gsi_observer2.out 
   # once observer has completed, check log files.
   set hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
   if ($hybrid_done == 'yes') then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   endif
endif

# compute ensemble mean analyses.
echo "$analdate starting ens mean analysis computation `date`"
csh ${enkfscripts}/compute_ensmean_enkf.csh >&!  ${current_logdir}/compute_ensmean_anal.out
echo "$analdate done computing ensemble mean analyses `date`"
