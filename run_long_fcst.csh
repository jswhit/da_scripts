echo "run_long_fcst"
# run high-res long forecast

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

if ($machine == 'gaea') then
   set python=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/python
else
   set python=`which python`
endif
# interpolate to 1x1 grid
cd ${enkfscripts}
$python ncinterp.py ${DATOUT}/${charnanal} fv3_historyp_latlon.nc $RES_CTL

cat ${machine}_preamble_hpss hpss_longfcst.sh >! job_hpss_longfcst.sh
if ($machine == 'wcoss') then
   bsub -env "all" < job_hpss_longfcst.sh
else if ($machine == 'gaea') then
   msub -V job_hpss_longfcst.sh
else if ($machine == 'cori') then
   sbatch --export=ALL job_hpss_longfcst.sh
else
   qsub -V job_hpss_longfcst.sh
endif
