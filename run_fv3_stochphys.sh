# model was compiled with these 
echo "staring at `date`"
if [ "$machine" == 'theia' ]; then
   module list
   module load intel/15.1.133
   module load impi/5.0.3.048
   module load netcdf/4.3.0
   module load esmf/7.0.0
fi

export VERBOSE=${VERBOSE:-"NO"}
if [ "$VERBOSE" == "YES" ]; then
 set -x
fi

nmem=`echo $charnanal | cut -f3 -d"m"`
export imem=10#$nmem
export ISEED_SPPT=$((analdate*1000 + imem*10 + 1))
export ISEED_SKEB=$((analdate*1000 + imem*10 + 2))
export ISEED_SHUM=$((analdate*1000 + imem*10 + 3))
export npx=`expr $RES + 1`
export LEVP=`expr $LEVS \+ 1`
export year=`echo $analdate |cut -c 1-4`
export mon=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`
export yrp1=`echo $analdatep1 |cut -c 1-4`
export monp1=`echo $analdatep1 |cut -c 5-6`
export dayp1=`echo $analdatep1 |cut -c 7-8`
export hrp1=`echo $analdatep1 |cut -c 9-10`


# copy data, diag and field tables.
cd ${datapath2}/${charnanal}
if [ $? -ne 0 ]; then
  echo "cd to ${datapath2}/${charnanal} failed, stopping..."
  exit 1
fi
/bin/cp -f $enkfscripts/diag_table .
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
if [ "$fg_only" == "true" ]; then
   for file in ../*nc; do
       file2=`basename $file`
       ln -fs $file $file2
   done
fi

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

# create netcdf increment file.
if [ "$fg_only" == "false" ]; then
   cd INPUT
   export increment_file="fv3_increment.nc"
   /bin/rm -f ${increment_file}
   cat > calc-increment.input <<EOF
&share
debug=F
analysis_filename="${datapath2}/sanl_${analdate}_${charnanal}"
firstguess_filename="${datapath2}/sfg_${analdate}_fhr06_${charnanal}"
increment_filename="${increment_file}"
/
EOF
   nprocs_save=$nprocs
   mpitaskspernode_save=$mpitaskspernode
   export nprocs=1
   export mpitaskspernode=1
   export PGM=${execdir}/calc_increment.x
   sh ${enkfscripts}/runmpi
   #${execdir}/calc_increment.x
   if [ $? -ne 0 -o ! -s ${increment_file} ]; then
      echo "problem creating ${increment_file}, stopping .."
      exit 1
   fi
   export nprocs=$nprocs_save
   export mpitaskspernode=$mpitaskspernode_save
   cd ..
fi

# setup model namelist
if [ "$fg_only" == "true" ]; then
   # cold start from chgres'd GFS analyes
   warm_start=F
   make_nh=T
   externalic=T
   reslatlondynamics=""
   mountain=F
   readincrement=F
   na_init=1
   FHCYC=0
else
   # warm start from restart file with lat/lon increments ingested by the model
   warm_start=T
   make_nh=F
   externalic=F
   reslatlondynamics="${increment_file}"
   readincrement=T
   mountain=T
   na_init=0 
   FHCYC=6
fi

snoid='SNOD'

# if next sst,snow,ice analyses available, use them in surface cycling
#fntsfa=${datapath2}/${charnanal}/sstgrb
#fnacna=${datapath2}/${charnanal}/engicegrb
#if [ -s ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.sstgrb ]; then
#  cat ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.sstgrb ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.sstgrb > ${fntsfa}
#else
#  ln -fs ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.sstgrb ${fntsfa}
#fi
#if [ -s ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.snogrb ]; then
#  cat ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.snogrb ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.snogrb > ${datapath2}/${charnanal}/snogrb
#else
#  ln -fs ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.snogrb ${datapath2}/${charnanal}/snogrb
#fi
#if [ -s ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.engicegrb ]; then
#  cat ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.engicegrb ${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.engicegrb > ${fnacna}
#else
#  ln -fs ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.engicegrb ${fnacna}
#fi
## check for missing snow depth
#nrecs_snow=`$WGRIB ${datapath2}/${charnanal}/snogrb | grep -i $snoid | wc -l`
#fsnol=0
#if [ $nrecs_snow -eq 0 ]; then
#   fnsnoa='        '
#   fsnol=99909
#   echo "no current snow analysis, use model"
#elif [ $nrecs_snow -eq 1 ]; then
#   echo "one bad snogrb record, check individual files..."
#   nrecs_snow=`$WGRIB ${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.snogrb | grep -i $snoid | wc -l`
#   if [ $nrecs_snow -eq 1 ]; then
#      fnsnoa=${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.snogrb
#   else
#      fnsnoa=${obs_datapath}/bufr_${analdatep1}/gdas1.t${hrp1}z.snogrb
#   fi
#else
#   fnsnoa=${datapath2}/${charnanal}/snogrb
#fi

# Turn off snow analysis if it has already been used.
# (snow analysis only available once per day at 18z)
fntsfa=${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.sstgrb
fnacna=${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.engicegrb
fnsnoa=${obs_datapath}/bufr_${analdate}/gdas1.t${hour}z.snogrb
nrecs_snow=`$WGRIB ${fnsnoa} | grep -i $snoid | wc -l`
if [ $nrecs_snow -eq 0 ]; then
   # no snow depth in file, use model
   fnsnoa='        ' # no input file
   fsnol=99999 # use model value
   echo "no snow depth in file, use model"
else
   # snow depth in file, but is it current?
   if [ `$WGRIB -4yr ${fnsnoa} 2>/dev/null|grep -i $snoid |\
         awk -F: '{print $3}'|awk -F= '{print $2}'` -le \
        `$WGRIB -4yr ${fnsnoa} 2>/dev/null |grep -i $snoid  |\
               awk -F: '{print $3}'|awk -F= '{print $2}'` ] ; then
      echo "no snow analysis, use model"
      fnsnoa='        ' # no input file
      fsnol=99999 # use model value
   else
      echo "snow analysis found, replace model"
      fsnol=0 # use analysis value
   fi
fi

ls -l 

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
restart_interval:        ${ANALINC}
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
  make_nh = ${make_nh},
  fv_debug = F,
  range_warn = F,
  reset_eta = F,
  n_sponge = 24,
  nudge_qv = T,
  tau = 5.0,
  rf_cutoff = 750.0,
  d2_bg_k1 = 0.15,
  d2_bg_k2 = 0.02,
  kord_tm = -9,
  kord_mt = 9,
  kord_wz = 9,
  kord_tr = 9,
  hydrostatic = ${hydrostatic},
  phys_hydrostatic = F,
  use_hydro_pressure = F,
  beta = 0,
  a_imp = 1.0,
  p_fac = 0.1,
  k_split  = ${k_split:-2},
  n_split  = ${n_split:-6},
  nwat = 2,
  na_init = ${na_init},
  d_ext = 0.0,
  dnats = 0,
  fv_sg_adj = ${fv_sg_adj:-600},
  d2_bg = 0.0,
  nord = 2,
  dddmp = 0.1,
  d4_bg = 0.12,
  delt_max = 0.002,
  vtdm4 = ${vtdm4},
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
  hord_mt = ${hord_mt},
  hord_vt = ${hord_vt},
  hord_tm = ${hord_tm},
  hord_dp = ${hord_dp},
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
  do_skeb=${do_skeb},SKEB_NPASS=$SKEB_NPASS
/

&external_ic_nml
  filtered_terrain = T,
  ncep_plevels = T,
  levp = $LEVP,
  gfs_dwinds = T,
  checker_tr = F,
  nt_checker = 0,
/

&gfs_physics_nml
  fhzero         = ${FHOUT}
  ldiag3d        = F
  fhcyc          = ${FHCYC}
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
  fnalbc = "${FIXGLOBAL}/global_snowfree_albedo.bosu.t1534.3072.1536.rg.grb",
  fnalbc2 = "${FIXGLOBAL}/global_albedo4.1x1.grb"
  fnaisc = "${FIXGLOBAL}/CFSR.SEAICE.1982.2012.monthly.clim.grb",
  fntg3c = "${FIXGLOBAL}/global_tg3clim.2.6x1.5.grb",
  fnvegc = "${FIXGLOBAL}/global_vegfrac.0.144.decpercent.grb",
  fnvetc = "${FIXGLOBAL}/global_vegtype.igbp.t1534.3072.1536.rg.grb",
  fnsmcc = "${FIXGLOBAL}/global_soilmgldas.t1534.3072.1536.grb",
  fnsotc = "${FIXGLOBAL}/global_soiltype.statsgo.t1534.3072.1536.rg.grb",
  fnmskh = "${FIXGLOBAL}/seaice_newland.grb",
  fntsfa = "${fntsfa}",
  fnacna = "${fnacna}",
  fnsnoa = "${fnsnoa}",
  fnvmnc = "${FIXGLOBAL}/global_shdmin.0.144x0.144.grb",
  fnvmxc = "${FIXGLOBAL}/global_shdmax.0.144x0.144.grb",
  fnslpc = "${FIXGLOBAL}/global_slope.1x1.grb",
  fnabsc = "${FIXGLOBAL}/global_mxsnoalb.uariz.t1534.3072.1536.rg.grb",
  ldebug = F,
  fsmcl(2) = 60,
  fsmcl(3) = 60,
  fsmcl(4) = 60,
  ftsfs = 0,
  faiss = 0,
  fsnol = ${fsnol},
  fsicl = 99999,
  ftsfl = 99999,
  faisl = 0,
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
  lon_s=$LONB, lat_s=$LATB, ntrunc=$JCAP,
  SHUM=$SHUM, -999., -999., -999, -999,SHUM_TAU=$SHUM_TSCALE, 1.728E5, 6.912E5, 7.776E6, 3.1536E7,SHUM_LSCALE=$SHUM_LSCALE, 1000.E3, 2000.E3, 2000.E3, 2000.E3,
  SPPT=$SPPT, -999., -999., -999, -999,SPPT_TAU=$SPPT_TSCALE,2592500,25925000,7776000,31536000,SPPT_LSCALE=$SPPT_LSCALE,1000000,2000000,2000000,2000000,SPPT_LOGIT=.TRUE.,SPPT_SFCLIMIT=.TRUE.,
  SKEBNORM=$SKEBNORM,
  SKEB=$SKEB, -999, -999, -999, -999,
  SKEB_TAU=$SKEB_TSCALE, 1.728E5, 2.592E6, 7.776E6, 3.1536E7,
  SKEB_LSCALE=$SKEB_LSCALE, 1000.E3, 2000.E3, 2000.E3, 2000.E3,
  SKEB_VDOF=$SKEB_VDOF,
  ISEED_SPPT=$ISEED_SPPT,ISEED_SHUM=$ISEED_SHUM,ISEED_SKEB=$ISEED_SKEB
/
EOF

# ftsfs = 99999 means all climo or all model, 0 means all analysis,
# 90 mean relax to climo
# with an e-folding time scale of 90 days.

cat input.nml
ls -l INPUT

# run model
export PGM=$FCSTEXEC
echo "start running model `date`"
sh ${enkfscripts}/runmpi
if [ $? -ne 0 ]; then
   echo "model failed..."
   exit 1
else
   echo "done running model, now post-process.. `date`"
fi
ls -l RESTART

# regrid output to NEMSIO
export PGM=${execdir}/regrid_nemsio

export OMP_NUM_THREADS=`python -c "import math; print int(math.floor(float(${fg_proc})/float(${LEVP})))"`
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`
if [ "$machine" == 'theia' ]; then
   if [ $OMP_NUM_THREADS -gt 1 ]; then
      HOSTFILE2="${HOSTFILE}_2"
      awk "NR%${OMP_NUM_THREADS} == 1" ${HOSTFILE} > $HOSTFILE2
      export HOSTFILE=$HOSTFILE2
      cat $HOSTFILE
   fi
fi

export nprocs=$LEVP

ncdump -v time fv3_history.tile1.nc
ncdump -v time fv3_history2d.tile1.nc
ntry=0
while [ $ntry -lt $nitermax ]; do
fh=$FHMIN
filemissing=0
while [ $fh -le $FHMAX ]; do
  charfhr="fhr"`printf %02i $fh`
  if [ ! -s ${datapathp1}/sfg_${analdatep1}_${charfhr}_${charnanal} ]; then
    filemissing=1
  fi
  if [ ! -s ${datapathp1}/bfg_${analdatep1}_${charfhr}_${charnanal} ]; then
    filemissing=1
  fi
  fh=$[$fh+$FHOUT]
done
if [ $filemissing -eq 1 ]; then
cat > regrid-nemsio.input <<EOF
&share
debug=T,nlons=$LONB,nlats=$LATB,ntrunc=$JCAP,
datapathout2d='${datapathp1}/bfg_${analdatep1}_${charnanal}',
datapathout3d='${datapathp1}/sfg_${analdatep1}_${charnanal}',
analysis_filename='fv3_history.tile1.nc','fv3_history.tile2.nc','fv3_history.tile3.nc','fv3_history.tile4.nc','fv3_history.tile5.nc','fv3_history.tile6.nc',
analysis_filename2d='fv3_history2d.tile1.nc','fv3_history2d.tile2.nc','fv3_history2d.tile3.nc','fv3_history2d.tile4.nc','fv3_history2d.tile5.nc','fv3_history2d.tile6.nc',
forecast_timestamp='${analdate}',
variable_table='${enkfscripts}/variable_table.txt.da',
nemsio_opt='bin4'
/
&interpio
gfs_hyblevs_filename='${enkfscripts}/global_hyblev.l${LEVP}.txt',
esmf_bilinear_filename='$FIXFV3/C${RES}/fv3_SCRIP_C${RES}_GRIDSPEC_lon${LONB}_lat${LATB}.gaussian.bilinear.nc'
esmf_neareststod_filename='$FIXFV3/C${RES}/fv3_SCRIP_C${RES}_GRIDSPEC_lon${LONB}_lat${LATB}.gaussian.neareststod.nc'
/
EOF
sh ${enkfscripts}/runmpi

# rename nemsio files
echo "rename output files, copy data"
fh=$FHMIN
while [ $fh -le $FHMAX ]; do
  charfhr1="fhr"`printf %03i $fh`
  charfhr2="fhr"`printf %02i $fh`
  /bin/mv -f ${datapathp1}/sfg_${analdatep1}_${charnanal}.${charfhr1} ${datapathp1}/sfg_${analdatep1}_${charfhr2}_${charnanal}
  /bin/mv -f ${datapathp1}/bfg_${analdatep1}_${charnanal}.${charfhr1} ${datapathp1}/bfg_${analdatep1}_${charfhr2}_${charnanal}
  fh=$[$fh+$FHOUT]
done
/bin/rm -f ${datapathp1}/sfg*fhr000
/bin/rm -f ${datapathp1}/bfg*fhr000
fi
ntry=$[$ntry+1]
done


# copy restart file to INPUT directory for next analysis time.
/bin/rm -rf ${datapathp1}/${charnanal}/RESTART ${datapathp1}/${charnanal}/INPUT
mkdir -p ${datapathp1}/${charnanal}/INPUT
cd RESTART
ls -l
datestring="${yrp1}${monp1}${dayp1}.${hrp1}0000."
for file in ${datestring}*nc; do
   file2=`echo $file | cut -f3-10 -d"."`
   /bin/mv -f $file ${datapathp1}/${charnanal}/INPUT/$file2
done
cd ..
ls -l ${datapathp1}/${charnanal}/INPUT

# remove symlinks from INPUT directory
cd INPUT
find -type l -delete
cd ..
/bin/rm -rf RESTART # don't need RESTART dir anymore.
#/bin/rm -f ${datapath2}/${charnanal}/sstgrb
#/bin/rm -f ${datapath2}/${charnanal}/snogrb
#/bin/rm -f ${datapath2}/${charnanal}/engicegrb

echo "all done at `date`"
exit 0
