echo "run_long_fcst"
# run high-res long forecast
if ($machine == 'gaea') then
   set python=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/python
   setenv PYTHONPATH /ncrc/home2/Jeffrey.S.Whitaker/anaconda2/lib/python2.7/site-packages
else if ($machine == 'theia') then
   set python=/contrib/anaconda/2.3.0/bin/python
endif

setenv write_tasks 6
setenv write_groups 1
# don't copy restart files.
setenv dont_copy_restart 1
# skip running calc_increment
setenv skip_calc_increment 1
# skip running global_cycle
setenv skip_global_cycle 1
# copy netcdf history files to DATOUT
setenv copy_history_files 1
# turn off quilting (no nemsio files output)
setenv quilting ".false."

setenv DATOUT "${datapath2}/longfcst"
echo "DATOUT = $DATOUT"
mkdir -p ${DATOUT}
setenv DIAG_TABLE "${enkfscripts}/diag_table_long"
echo "DIAG_TABLE = $DIAG_TABLE"

setenv OMP_NUM_THREADS $control_threads
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"
setenv nprocs `expr $control_proc \/ $OMP_NUM_THREADS`
echo "nprocs = $nprocs"
setenv mpitaskspernode `expr $corespernode \/ $OMP_NUM_THREADS`
echo "mpitaskspernode = $mpitaskspernode"
if ($machine == 'theia') then
   if ($OMP_NUM_THREADS == 1) then
      setenv HOSTFILE $PBS_NODEFILE
   else
      setenv HOSTFILE ${datapath2}/hostfile_control
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} >&! $HOSTFILE
   endif
   echo "HOSTFILE = $HOSTFILE"
endif

setenv RES $RES_CTL
echo "RES = $RES"
setenv dt_atmos $dt_atmos_ctl
echo "dt_atmos = $dt_atmos"
setenv fv_sg_adj $fv_sg_adj_ctl
echo "fv_sg_adj = $fv_sg_adj"
setenv cdmbgwd "$cdmbgwd_ctl"
echo "cdmbgwd = $cdmbgwd"
if ($?psautco_ctl) then
setenv psautco "$psautco_ctl"
echo "psautco = $psautco"
endif
if ($?prautco_ctl) then
setenv prautco "$psautco_ctl"
echo "prautco = $psautco"
endif
setenv fg_proc $nprocs
echo "fg_proc = $fg_proc"
setenv layout "$layout_ctl"
echo "layout = $layout"
setenv FHMAX $FHMAX_LONG
echo "FHMAX = $FHMAX"
setenv FHRESTART $FHMAX
setenv LONB $LONB_CTL
echo "LONB = $LONB"
setenv LATB $LATB_CTL
echo "LATB = $LATB"

# turn off stochastic physics
setenv SKEB 0
setenv SPPT 0
setenv SHUM 0
echo "SKEB SPPT SHUM = $SKEB $SPPT $SHUM"

sh ${enkfscripts}/${rungfs}

# interpolate pressure level history files to 1x1 grid
echo "interpolate pressure level history files to 1x1 deg grid`date`"
cd ${enkfscripts}
$python ncinterp.py ${DATOUT}/${charnanal} ${datapath2}/fv3long${charnanal}_historyp_${analdate}_latlon.nc $RES_CTL ${analdate}
if ($status == 0) then
   /bin/rm -rf ${DATOUT} 
   echo "yes" >&! ${current_logdir}/run_long_fcst.log
   exit 0
else
   echo "no" >&! ${current_logdir}/run_long_fcst.log
   exit 1
endif
echo "all done `date`"
