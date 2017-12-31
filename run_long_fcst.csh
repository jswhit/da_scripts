echo "run_long_fcst"
# run high-res long forecast

setenv write_tasks 6
setenv write_groups 1
#if ($quilting == '.false.') then
#   echo "no nemsio files will be produced"
#   set layoutx=`echo $layout_ctl | cut -f1 -d","`
#   set layouty=`echo $layout_ctl | cut -f2 -d","`
#   set control_proc=`expr $layoutx \* $layouty \* $control_threads \* 6`
#   setenv layout $layout_ctl
#endif
setenv layout $layout_ctl

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
else if ($controlfcst == 'false') then
   setenv charnanal "ensmean"
   unsetenv skip_calc_increment
   unsetenv skip_global_cycle
else
   setenv charnanal "control"
endif
echo "charnanal = $charnanal"
setenv DATOUT "${datapath2}/longfcst"
echo "DATOUT = $DATOUT"
mkdir -p ${DATOUT}
if ($quilting == ".false.") then
  setenv DIAG_TABLE "${enkfscripts}/diag_table_long"
  echo "DIAG_TABLE = $DIAG_TABLE"
else
  setenv DIAG_TABLE "${enkfscripts}/diag_table"
  echo "DIAG_TABLE = $DIAG_TABLE"
endif

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

#if ($quilting == ".true.") then
#   # now run post processor
#   setenv nprocs `expr $NODES \* $corespernode`
#   if ($nprocs > 240) then
#     setenv nprocs 240
#   endif
#   csh ${enkfscripts}/post.csh
#   # clean up: delete bfg, sfg files
#   rm $DATOUT/bfg_*
#   rm $DATOUT/sfg_*
#   rm $DATOUT/outpost*
#   rm $DATOUT/postgp.inp*
#endif
#
#unsetenv LSB_SUB_RES_REQ 
#if ($machine == 'wcoss') then
#  cd ${enkfscripts}
#  bsub -env "all" < hpss_longfcst.sh
#endif
