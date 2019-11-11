echo "$analdate run high-res control long fcst `date`"
#export FHMAX_LONG=120
export FHMAX_LONG=${FHMAX_LONG:-120}
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

export control_proc=$control_proc_noquilt

env
export submit_hpss=true
#csh ${enkfscripts}/run_long_fcst.csh
echo "run_long_fcst"
# run high-res long forecast

export write_tasks=6
export write_groups=1
# don't copy restart files.
export dont_copy_restart=1
# skip running calc_increment
export skip_calc_increment=1
# skip running global_cycle
export skip_global_cycle =
# copy netcdf history files to DATOUT
export copy_history_files=1
#!/bin/sh
# turn off quilting (no nemsio files output)
export quilting=".false."

export DATOUT="${datapath2}/longfcst"
echo "DATOUT = $DATOUT"
mkdir -p ${DATOUT}
export DIAG_TABLE="${enkfscripts}/diag_table_full"
echo "DIAG_TABLE = $DIAG_TABLE"

export OMP_NUM_THREADS=$control_threads
export OMP_STACKSIZE=256M
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"
export nprocs=`expr $control_proc \/ $OMP_NUM_THREADS`
echo "nprocs = $nprocs"
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`
echo "mpitaskspernode = $mpitaskspernode"

export RES=$RES_CTL
echo "RES = $RES"
export dt_atmos=$dt_atmos_ctl
echo "dt_atmos = $dt_atmos"
export fv_sg_adj=$fv_sg_adj_ctl
echo "fv_sg_adj = $fv_sg_adj"
export cdmbgwd="$cdmbgwd_ctl"
echo "cdmbgwd = $cdmbgwd"
if [ ! -z $psautco_ctl ]; then
export psautco="$psautco_ctl"
echo "psautco = $psautco"
fi
if [ ! -z $prautco_ctl ]; then
export prautco="$psautco_ctl"
echo "prautco = $psautco"
fi
if [ ! -z $k_split_ctl ]; then
export k_split="${k_split_ctl}"
fi
if [ ! -z $n_split_ctl ]; then
export n_split="${n_split_ctl}"
fi
export fg_proc=$nprocs
echo "fg_proc = $fg_proc"
export layout="$layout_ctl"
echo "layout = $layout"
export FHMAX=$FHMAX_LONG
echo "FHMAX = $FHMAX"
export FHRESTART=$FHMAX
export LONB=$LONB_CTL
echo "LONB = $LONB"
export LATB=$LATB_CTL
echo "LATB = $LATB"

# turn off stochastic physics
export SKEB=0
export SPPT=0
export SHUM=0
echo "SKEB SPPT SHUM = $SKEB $SPPT $SHUM"

sh ${enkfscripts}/${rungfs}

# interpolate pressure level history files to 1x1 grid
echo "interpolate pressure level history files to 1x1 deg grid `date`"
cd ${enkfscripts}
$python ncinterp.py ${DATOUT}/${charnanal} ${datapath2}/fv3long${charnanal}_historyp_${analdate}_latlon.nc $RES_CTL ${analdate}
status=$?
if [ $status -eq 0 ]; then
   /bin/rm -rf ${DATOUT} 
   echo "yes" > ${current_logdir}/run_long_fcst.log
   echo "all done `date`"
else
   echo "no" > ${current_logdir}/run_long_fcst.log
   echo "failed `date`"
fi
