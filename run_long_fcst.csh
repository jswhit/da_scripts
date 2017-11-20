# run high-res long forecast

if ($quilting == '.false.') then
   echo "no nemsio files will be produced"
   if ($NODES == 20) then
      # 20 nodes, 2 threads
      setenv control_threads 2 # control forecast threads
      setenv control_proc 480  
      setenv layout_ctl "10, 4" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($control_proc-$write_tasks)/control_threads)
   else if ($NODES == 40) then
      # 40 nodes, 2 threads
      setenv control_threads 2 # control forecast threads
      setenv control_proc 960  
      setenv layout_ctl "10, 8" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($control_proc-$write_tasks)/control_threads)
   else
      echo "processor layout for $NODES nodes not set"
      exit 1
   endif
endif

# don't copy restart files.
setenv dont_copy_restart 1
# skip running calc_increment
setenv skip_calc_increment 1
# skip running global_cycle
setenv skip_global_cycle 1
# copy netcdf history files to DATOUT
setenv copy_history_files 1

if ($replay_controlfcst == 'true') then
   setenv charnanal "control2"
else
   setenv charnanal "control"
endif
echo "charnanal = $charnanal"
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
if ($machine != 'wcoss') then
   setenv HOSTFILE $PBS_NODEFILE
   echo "HOSTFILE = $HOSTFILE"
endif

setenv RES $RES_CTL
echo "RES = $RES"
setenv write_groups "$write_groups_ctl"
echo "write_groups = $write_groups"
setenv layout "$layout_ctl"
echo "layout = $layout"
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
setenv FHMAX $FHMAX_LONG
echo "FHMAX = $FHMAX"
setenv FHRESTART $FHMAX

# turn off stochastic physics
setenv SKEB 0
setenv SPPT 0
setenv SHUM 0
echo "SKEB SPPT SHUM = $SKEB $SPPT $SHUM"

sh ${enkfscripts}/${rungfs}
