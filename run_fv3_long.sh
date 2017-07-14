#BSUB -W 2:00                    # wall clock time 
#BSUB -o fv3_long.stdout
#BSUB -e fv3_long.stderr
#BSUB -J fv3_long
#BSUB -q "dev"                   # job queue 
#BSUB -P GFS-T2O                 # project code 
#BSUB -M 400                     # Memory req's for serial portion
#BSUB -extsched 'CRAYLINUX[]'    # Request to run on compute nodes
export NODES=3
export corespernode=24
export machine='wcoss'
# allow this script to submit other scripts on WCOSS
unset LSB_SUB_RES_REQ

export fg_proc=`expr $NODES \* $corespernode` # number of cores per enkf fg ens member.
export fg_threads=1 # ens fcst threads
export OMP_NUM_THREADS=$fg_threads
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`

export VERBOSE=${VERBOSE:-"YES"}
if [ "$VERBOSE" == "YES" ]; then
 set -x
fi

export exptname=C96_singleres_fv3nems

export RES=96  
export LEVS=64
export LEVP=`expr $LEVS \+ 1`
export JCAP=126 
export LONB=384   
export LATB=190  
export FHMAX=240
export FHOUT=24
export FHZER=$FHOUT
export cdmbgwd="0.125, 3.0"
export fv_sg_adj=0
export dt_atmos=900
# suggested nyblocks=`expr \( $RES \) \/ $layout_y `
# suggested nxblocks=`expr \( $RES \) \/ $layout_x \/ 32`
if [ "$NODES" == "12" ]; then
  export layout="6, 8" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=fg_proc/fg_threads)
  export nyblocks=24
  export nxblocks=1
else
  export layout="3, 4"
  export nyblocks=48
  export nxblocks=2
fi
export npx=`expr $RES + 1`
export enkfscripts=/gpfs/hps2/esrl/gefsrr/noscrub/${USER}/scripts/${exptname}
export execdir=${enkfscripts}/exec
export fv3gfspath=/gpfs/hps3/emc/global/noscrub/emc.glopara/svn/fv3gfs
export FIXFV3=${fv3gfspath}/fix_fv3
export FIXGLOBAL=${fv3gfspath}/fix/fix_am
export FCSTEXEC=${execdir}/fv3.exe

export obs_datapath=/gpfs/hps2/esrl/gefsrr/noscrub/cfsr_dumps
export datapath=/gpfs/hps2/ptmp/${USER}/${exptname}
export datapath2=${datapath}/${analdate}
export hsidir="/3year/NCEPDEV/GEFSRR/${USER}/${exptname}"

# run forecast from ensemble mean analysis, then CFSR analysis.

nfcst=1
while [ $nfcst -le 2 ]; do
export nprocs=`expr $fg_proc \/ $OMP_NUM_THREADS`

if [ "$nfcst" == "1" ]; then
   export charnanal='ensmean'
   warm_start=T
   externalic=F
   reslatlondynamics="fv3_increment.nc"
   readincrement=T
   mountain=T
else
   export charnanal='cfsr'
   mkdir -p ${datapath2}/${charnanal}/INPUT
   /bin/cp -f /gpfs/hps2/esrl/gefsrr/noscrub/Jeffrey.S.Whitaker/cfsrics/C${RES}_${analdate}/control/* ${datapath2}/${charnanal}/INPUT
   warm_start=F
   externalic=T
   reslatlondynamics=""
   mountain=F
   readincrement=F
fi

export LEVP=`expr $LEVS \+ 1`
export year=`echo $analdate |cut -c 1-4`
export mon=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`


# copy data, diag and field tables.
cd ${datapath2}/${charnanal}
/bin/cp -f $enkfscripts/diag_table_long diag_table
/bin/cp -f $enkfscripts/nems.configure .
# for diag table, insert correct starting time.
sed -i -e "s/YYYY MM DD HH/${year} ${mon} ${day} ${hour}/g" diag_table
#FHMAXP1=`expr $FHMAX + 1`
#fdiag=`python -c "print range(${FHMIN},${FHMAXP1},${FHOUT})" | cut -f2 -d"[" | cut -f1 -d"]"`
#sed -i -e "s/FHOUT/${FHOUT}/g" diag_table
/bin/cp -f $enkfscripts/field_table .
/bin/cp -f $enkfscripts/data_table . 
/bin/rm -rf RESTART
mkdir -p RESTART
mkdir -p INPUT

# make symlinks for fixed files and initial conditions.
cd INPUT
# Grid and orography data
n=1
while [ $n -le 6 ]; do
 ln -fs $FIXFV3/C${RES}/C${RES}_grid.tile${n}.nc     C${RES}_grid.tile${n}.nc
 ln -fs $FIXFV3/C${RES}/C${RES}_oro_data.tile${n}.nc oro_data.tile${n}.nc
 n=$((n+1))
done
ln -fs $FIXFV3/C${RES}/C${RES}_mosaic.nc  grid_spec.nc
ln -fs $FIXGLOBAL/global_o3prdlos.f77               global_o3prdlos.f77
cd ..
# co2, ozone, surface emiss and aerosol data.
ln -fs $FIXGLOBAL/global_solarconstant_noaa_an.txt  solarconstant_noaa_an.txt
ln -fs $FIXGLOBAL/global_sfc_emissivity_idx.txt     sfc_emissivity_idx.txt
ln -fs $FIXGLOBAL/global_co2historicaldata_glob.txt co2historicaldata_glob.txt
ln -fs $FIXGLOBAL/co2monthlycyc.txt                 co2monthlycyc.txt
for file in `ls $FIXGLOBAL/co2dat_4a/global_co2historicaldata* ` ; do
   ln -fs $file $(echo $(basename $file) |sed -e "s/global_//g")
done
ln -fs $FIXGLOBAL/global_climaeropac_global.txt     aerosol.dat
for file in `ls $FIXGLOBAL/global_volcanic_aerosols* ` ; do
   ln -fs $file $(echo $(basename $file) |sed -e "s/global_//g")
done

cat > model_configure <<EOF
total_member:            1
PE_MEMBER01:             ${nprocs}
start_year:              ${year}
start_month:             ${mon}
start_day:               ${day}
start_hour:              ${hour}
start_minute:            0
start_second:            0
nhours_fcst:             ${FHMAX}
RUN_CONTINUE:            F
ENS_SPS:                 F
dt_atmos:                ${dt_atmos} 
calendar:                'julian'
memuse_verbose:          F
atmos_nthreads:          ${OMP_NUM_THREADS}
use_hyper_thread:        F
ncores_per_node:         ${corespernode}
restart_interval:        ${FHMAX}
EOF
#restart_interval:        `expr ${ANALINC} \* 3600`
cat model_configure

cat > input.nml <<EOF
&amip_interp_nml
  interp_oi_sst = T,
  use_ncep_sst = T,
  use_ncep_ice = F,
  no_anom_sst = F,
  data_set = "reynolds_oi",
  date_out_of_range = "climo",
/

&atmos_model_nml
  blocksize = 32,
  dycore_only = F,
/
&diag_manager_nml
  prepend_date = F,
/

&fms_io_nml
  checksum_required = F,
  max_files_r = 100,
  max_files_w = 100,
/

&fms_nml
  clock_grain = "ROUTINE",
  domains_stack_size = 115200,
  print_memory_usage = F,
/

&fv_core_nml
  layout = ${layout},
  io_layout = 1, 1,
  npx      = ${npx},
  npy      = ${npx},
  npz      = ${LEVS},
  ntiles = 6,
  grid_type = -1,
  make_nh = F,
  fv_debug = F,
  range_warn = F,
  reset_eta = F,
  n_sponge = 13,
  nudge_qv = T,
  tau = 5.0,
  rf_cutoff = 750.0,
  d2_bg_k1 = 0.15,
  d2_bg_k2 = 0.02,
  kord_tm = -9,
  kord_mt = 9,
  kord_wz = 9,
  kord_tr = 9,
  hydrostatic = T,
  phys_hydrostatic = F,
  use_hydro_pressure = F,
  beta = 0,
  a_imp = 1.0,
  p_fac = 0.1,
  k_split  = 1,
  n_split  = 6,
  nwat = 2,
  na_init = 0,
  d_ext = 0.0,
  dnats = 0,
  fv_sg_adj = ${fv_sg_adj:-600},
  d2_bg = 0.0,
  nord = 2,
  dddmp = 0.1,
  d4_bg = 0.12,
  delt_max = 0.002,
  vtdm4 = 0.05,
  ke_bg = 0.0,
  do_vort_damp = T,
  external_ic = $externalic,
  res_latlon_dynamics=$reslatlondynamics,
  read_increment=$readincrement,
  gfs_phil = F,
  nggps_ic = T,
  mountain = ${mountain},
  ncep_ic = F,
  d_con = 1.0,
  hord_mt = 10, 
  hord_vt = 10,
  hord_tm = 10,
  hord_dp = 5,
  hord_tr = 8,
  adjust_dry_mass = F,
  consv_te = 0,
  consv_am = F,
  fill = T,
  dwind_2d = F,
  print_freq = 6,
  warm_start = ${warm_start},
  no_dycore = F,
  z_tracer = T,
  do_skeb=F
/

&external_ic_nml
  filtered_terrain = T,
  ncep_plevels = F,
  levp = $LEVP,
  gfs_dwinds = T,
  checker_tr = F,
  nt_checker = 0,
/

&gfs_physics_nml
  fhzero         = ${FHOUT}
  ldiag3d        = F
  fhcyc          = 0
  nst_anl        = F
  use_ufo        = T
  pre_rad        = F
  ncld           = 1
  zhao_mic       = T
  pdfcld         = F
  fhswr          = 3600.
  fhlwr          = 3600.
  ialb           = 1
  iems           = 1
  IAER           = 111
  ico2           = 2
  isubc_sw       = 2
  isubc_lw       = 2
  isol           = 2
  lwhtr          = T
  swhtr          = T
  cnvgwd         = T
  shal_cnv       = T
  cal_pre        = T
  redrag         = T
  dspheat        = F
  hybedmf        = T
  random_clds    = T
  trans_trac     = T
  cnvcld         = T
  imfshalcnv     = 2
  imfdeepcnv     = 2
  prslrd0        = 0
  ivegsrc        = 1
  isot           = 1
  debug          = F
  nstf_name      = 0
  cdmbgwd = ${cdmbgwd}
/

&nggps_diag_nml
  fdiag = ${FHOUT}
/

&interpolator_nml
  interp_method = "conserve_great_circle",
/

&namsfc
  fnglac = "${FIXGLOBAL}/global_glacier.2x2.grb",
  fnmxic = "${FIXGLOBAL}/global_maxice.2x2.grb",
  fntsfc = "${FIXGLOBAL}/RTGSST.1982.2012.monthly.clim.grb",
  fnsnoc = "${FIXGLOBAL}/global_snoclim.1.875.grb",
  fnzorc = "igbp",
  fnalbc = "${FIXGLOBAL}/global_snowfree_albedo.bosu.t126.384.190.rg.grb",
  fnalbc2 = "${FIXGLOBAL}/global_albedo4.1x1.grb"
  fnaisc = "${FIXGLOBAL}/CFSR.SEAICE.1982.2012.monthly.clim.grb",
  fntg3c = "${FIXGLOBAL}/global_tg3clim.2.6x1.5.grb",
  fnvegc = "${FIXGLOBAL}/global_vegfrac.0.144.decpercent.grb",
  fnvetc = "${FIXGLOBAL}/global_vegtype.igbp.t126.384.190.rg.grb",
  fnsmcc = "${FIXGLOBAL}/global_soilmgldas.t126.384.190.grb",
  fnsotc = "${FIXGLOBAL}/global_soiltype.statsgo.t126.384.190.rg.grb",
  fnmskh = "${FIXGLOBAL}/seaice_newland.grb",
  fntsfa = "${datapath2}/${charnanal}/sstgrb",
  fnacna = "${datapath2}/${charnanal}/engicegrb",
  fnsnoa = "${fnsnoa}",
  fnvmnc = "${FIXGLOBAL}/global_shdmin.0.144x0.144.grb",
  fnvmxc = "${FIXGLOBAL}/global_shdmax.0.144x0.144.grb",
  fnslpc = "${FIXGLOBAL}/global_slope.1x1.grb",
  fnabsc = "${FIXGLOBAL}/global_mxsnoalb.uariz.t126.384.190.rg.grb",
  ldebug = F,
  fsmcl(2) = 99999,
  fsmcl(3) = 99999,
  fsmcl(4) = 99999,
  ftsfs = 90,
  faiss = 99999,
  fsnol = 99999,
  fsicl = 99999,
  ftsfl = 99999,
  faisl = 99999,
  fvetl = 99999,
  fsotl = 99999,
  fvmnl = 99999,
  fvmxl = 99999,
  fslpl = 99999,
  fabsl = 99999,
  fsnos = 99999,
  fsics = 99999,
/

&fv_grid_nml
  grid_file = "INPUT/grid_spec.nc",
/

&nam_stochy
  lon_s=$LONB, lat_s=$LATB, ntrunc=$JCAP
  SHUM=0,SPPT=0,SKEB=0
/
EOF

cat input.nml
ls -l INPUT

# run model
export PGM=$FCSTEXEC
sh ${enkfscripts}/runmpi
echo "done running model (status code $?), now post-process.."
ls -l RESTART

# regrid output to NEMSIO
export outpath=${datapath2}/longfcst/${charnanal}
mkdir -p $outpath
export nprocs=$LEVP
export PGM=${execdir}/regrid_nemsio
cat > regrid-nemsio.input <<EOF
&share
debug=T,nlons=$LONB,nlats=$LATB,ntrunc=$JCAP,
datapathout2d='${outpath}/sfc',
datapathout3d='${outpath}/sig',
analysis_filename='fv3_history.tile1.nc','fv3_history.tile2.nc','fv3_history.tile3.nc','fv3_history.tile4.nc','fv3_history.tile5.nc','fv3_history.tile6.nc',
analysis_filename2d='fv3_history2d.tile1.nc','fv3_history2d.tile2.nc','fv3_history2d.tile3.nc','fv3_history2d.tile4.nc','fv3_history2d.tile5.nc','fv3_history2d.tile6.nc',
forecast_timestamp='${analdate}',
variable_table='${enkfscripts}/variable_table.txt.da-grib'
nemsio_opt='grib'
/
&interpio
gfs_hyblevs_filename='${enkfscripts}/global_hyblev.l${LEVP}.txt',
esmf_bilinear_filename='${enkfscripts}/fv3_SCRIP_C${RES}_GRIDSPEC_gaussian_lon${LONB}_lat${LATB}.bilinear.nc'
esmf_neareststod_filename='${enkfscripts}/fv3_SCRIP_C${RES}_GRIDSPEC_gaussian_lon${LONB}_lat${LATB}.neareststod.nc'
/
EOF
sh ${enkfscripts}/runmpi

# now run unipost
export nprocs=72
csh ${enkfscripts}/post.csh

nfcst=$((nfcst+1))
done # do next forecast

echo "all done"

# tar up results to HPSS
cd $enkfscripts
bsub -env "all" < hpss_longfcst.sh
exit 0
