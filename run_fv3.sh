#!/bin/sh
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh
if [ "$machine" == 'hera' ]; then
   module purge
   module load intel/18.0.5.274
   module load impi/2018.0.4
   module load netcdf/4.7.0
   module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   module load esmflocal/8_0_0r
   module load wgrib
   export WGRIB=`which wgrib`
elif [ "$machine" == 'orion' ]; then
   module purge 
   module load intel/2019.5 
   module load impi/2019.6 
   module load mkl/2019.5  
   export NCEPLIBS=/apps/contrib/NCEPLIBS/lib
   module use -a /apps/contrib/NCEPLIBS/lib/modulefiles
   module load netcdfp/4.7.4
   module load esmflocal/8.0.0.para
   module load grib_util-intel-sandybridge # wgrib
elif [ "$machine" == 'gaea' ]; then
   module purge
   module load PrgEnv-intel/6.0.3
   module rm intel
   module load intel/18.0.3.222
   module load cray-netcdf
   module use -a /lustre/f2/pdata/ncep_shared/NCEPLIBS/lib//modulefiles
   module load esmflocal/8_0_48b
   module load nco/4.6.4
   module load wgrib
   export WGRIB=`which wgrib`
   export HDF5_DISABLE_VERSION_CHECK=1
fi
module list

export VERBOSE=${VERBOSE:-"NO"}
export quilting=${quilting:-'.true.'}
if [ "$VERBOSE" == "YES" ]; then

 set -x
fi

niter=${niter:-1}
if [ "$charnanal" != "control" ] && [ "$charnanal" != "ensmean" ] && [ "$charnanal" != "control2" ]; then
   nmem=`echo $charnanal | cut -f3 -d"m"`
   nmem=$(( 10#$nmem )) # convert to decimal (remove leading zeros)
else
   nmem=0
fi
charnanal2=`printf %02i $nmem`
export ISEED_SPPT=$((analdate*1000 + nmem*10 + 0 + niter))
export ISEED_SKEB=$((analdate*1000 + nmem*10 + 1 + niter))
export ISEED_SHUM=$((analdate*1000 + nmem*10 + 2 + niter))
#export ISEED_SPPT=$((analdate*1000 + nmem*10 + 0))
#export ISEED_SKEB=$((analdate*1000 + nmem*10 + 1))
#export ISEED_SHUM=$((analdate*1000 + nmem*10 + 2))
export npx=`expr $RES + 1`
export LEVP=`expr $LEVS \+ 1`
# yr,mon,day,hr at middle of assim window (analysis time)
export yeara=`echo $analdate |cut -c 1-4`
export mona=`echo $analdate |cut -c 5-6`
export daya=`echo $analdate |cut -c 7-8`
export houra=`echo $analdate |cut -c 9-10`
export yearprev=`echo $analdatem1 |cut -c 1-4`
export monprev=`echo $analdatem1 |cut -c 5-6`
export dayprev=`echo $analdatem1 |cut -c 7-8`
export hourprev=`echo $analdatem1 |cut -c 9-10`
if [ "${iau_delthrs}" != "-1" ]  && [ "${fg_only}" == "false" ]; then
   # start date for forecast (previous analysis time)
   export year=`echo $analdatem1 |cut -c 1-4`
   export mon=`echo $analdatem1 |cut -c 5-6`
   export day=`echo $analdatem1 |cut -c 7-8`
   export hour=`echo $analdatem1 |cut -c 9-10`
   # current date in restart (beginning of analysis window)
   export year_start=`echo $analdatem3 |cut -c 1-4`
   export mon_start=`echo $analdatem3 |cut -c 5-6`
   export day_start=`echo $analdatem3 |cut -c 7-8`
   export hour_start=`echo $analdatem3 |cut -c 9-10`
   # end time of analysis window (time for next restart)
   export yrnext=`echo $analdatep1m3 |cut -c 1-4`
   export monnext=`echo $analdatep1m3 |cut -c 5-6`
   export daynext=`echo $analdatep1m3 |cut -c 7-8`
   export hrnext=`echo $analdatep1m3 |cut -c 9-10`
else
   # if no IAU, start date is middle of window
   export year=`echo $analdate |cut -c 1-4`
   export mon=`echo $analdate |cut -c 5-6`
   export day=`echo $analdate |cut -c 7-8`
   export hour=`echo $analdate |cut -c 9-10`
   # date in restart file is same as start date (not continuing a forecast)
   export year_start=`echo $analdate |cut -c 1-4`
   export mon_start=`echo $analdate |cut -c 5-6`
   export day_start=`echo $analdate |cut -c 7-8`
   export hour_start=`echo $analdate |cut -c 9-10`
   # time for restart file
   if [ "${iau_delthrs}" != "-1" ] ; then
      # beginning of next analysis window
      export yrnext=`echo $analdatep1m3 |cut -c 1-4`
      export monnext=`echo $analdatep1m3 |cut -c 5-6`
      export daynext=`echo $analdatep1m3 |cut -c 7-8`
      export hrnext=`echo $analdatep1m3 |cut -c 9-10`
   else
      # end of next analysis window
      export yrnext=`echo $analdatep1 |cut -c 1-4`
      export monnext=`echo $analdatep1 |cut -c 5-6`
      export daynext=`echo $analdatep1 |cut -c 7-8`
      export hrnext=`echo $analdatep1 |cut -c 9-10`
   fi
fi


# copy data, diag and field tables.
cd ${datapath2}/${charnanal}
if [ $? -ne 0 ]; then
  echo "cd to ${datapath2}/${charnanal} failed, stopping..."
  exit 1
fi
/bin/rm -f dyn*.nc phy*nc
export DIAG_TABLE=${DIAG_TABLE:-$enkfscripts/diag_table}
/bin/cp -f $DIAG_TABLE diag_table
/bin/cp -f $enkfscripts/nems.configure .
# insert correct starting time and output interval in diag_table template.
sed -i -e "s/YYYY MM DD HH/${year} ${mon} ${day} ${hour}/g" diag_table
sed -i -e "s/FHOUT/${FHOUT}/g" diag_table
if [ "$imp_physics" == '99' ]; then
/bin/cp -f $enkfscripts/field_table .
else
/bin/cp -f $enkfscripts/field_table_ncld5 field_table
fi
/bin/cp -f $enkfscripts/data_table . 
/bin/rm -rf RESTART
mkdir -p RESTART
mkdir -p INPUT

# make symlinks for fixed files and initial conditions.
cd INPUT
if [ "$fg_only" == "true" ] && [ "$cold_start" == "true" ]; then
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
cd ..
#ln -fs $FIXGLOBAL/global_o3prdlos.f77               global_o3prdlos.f77
# new ozone and h2o physics for stratosphere
ln -fs $FIXGLOBAL/ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77 global_o3prdlos.f77
ln -fs $FIXGLOBAL/global_h2o_pltc.f77 global_h2oprdlos.f77 # used if h2o_phys=T
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

# create netcdf increment files.
if [ "$fg_only" == "false" ] && [ -z $skip_calc_increment ]; then
   cd INPUT

   iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
# IAU - multiple increments.
   for fh in $iaufhrs2; do
      export increment_file="fv3_increment${fh}.nc"
      if [ "$replay_controlfcst" == 'true' ] && [ "$charnanal" == 'control2' ]; then
         export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_ensmean"
         export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}.chgres"
      else
         export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_${charnanal}"
         export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}"
      fi
      echo "create ${increment_file}"
      /bin/rm -f ${increment_file}
      export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file} T F"
      nprocs=1 mpitaskspernode=1 ${enkfscripts}/runmpi
      if [ $? -ne 0 -o ! -s ${increment_file} ]; then
         echo "problem creating ${increment_file}, stopping .."
         exit 1
      fi
   done # do next forecast

   cd ..
fi

# setup model namelist
if [ "$fg_only" == "true" ]; then
   # cold start from chgres'd GFS analyes
   stochini=F
   if [ "$cold_start" == "true" ]; then
     warm_start=F
     externalic=T
     na_init=1
     mountain=F
     make_nh=T
   else
     warm_start=T
     externalic=F
     na_init=0
     mountain=T
     make_nh=F
   fi
   reslatlondynamics=""
   readincrement=F
   FHCYC=0
   iaudelthrs=-1
   iau_inc_files=""
else
   # warm start from restart file with lat/lon increments ingested by the model
   if [ $niter == 1 ] ; then
     if [ -s stoch_ini ]; then
       echo "stoch_ini available, setting stochini=T"
       stochini=T # restart random patterns from existing file
     else
       echo "stoch_ini not available, setting stochini=F"
       stochini=F
     fi
   elif [ $niter == 2 ]; then
      echo "WARNING: iteration ${niter}, setting stochini=F for ${charnanal}" > ${current_logdir}/stochini_fg_ens.log
      stochini=F
   else
      # last try, turn stochastic physics off
      echo "WARNING: iteration ${niter}, seting SPPT=0 for ${charnanal}" > ${current_logdir}/stochini_fg_ens.log
      SPPT=0
      SKEB=0
      SHUM=0
      # set to large value so no random patterns will be output
      # and random pattern will be reinitialized
      FHSTOCH=240
      # reduce model time step
      #dt_atmos=`python -c "print ${dt_atmos}/2"`
   fi
   
   iaudelthrs=${iau_delthrs}
   warm_start=T
   make_nh=F
   externalic=F
   mountain=T
   na_init=0 
   FHCYC=${FHCYC}
   if [ "${iau_delthrs}" != "-1" ]; then
      if [ "$iaufhrs" == "3,4,5,6,7,8,9" ]; then
         iau_inc_files="'fv3_increment3.nc','fv3_increment4.nc','fv3_increment5.nc','fv3_increment6.nc','fv3_increment7.nc','fv3_increment8.nc','fv3_increment9.nc'"
      elif [ "$iaufhrs" == "3,6,9" ]; then
         iau_inc_files="'fv3_increment3.nc','fv3_increment6.nc','fv3_increment9.nc'"
      elif [ "$iaufhrs" == "6" ]; then
         iau_inc_files="'fv3_increment6.nc'"
      else
         echo "illegal value for iaufhrs"
         exit 1
      fi
      reslatlondynamics=""
      readincrement=F
   else
      reslatlondynamics="fv3_increment6.nc"
      readincrement=T
      iau_inc_files=""
   fi
fi

#fntsfa=${sstpath}/${yeara}/sst_${charnanal2}.grib
#fnacna=${sstpath}/${yeara}/icec_${charnanal2}.grib
#fnsnoa='        ' # no input file, use model snow

snoid='SNOD'

# Turn off snow analysis if it has already been used.
# (snow analysis only available once per day at 18z)
fntsfa=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.rtgssthr.grb
fnacna=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.seaice.5min.grb
fnsnoa=${obs_datapath}/gdas.${yeara}${mona}${daya}/${houra}/gdas.t${houra}z.snogrb_t1534.3072.1536
fnsnog=${obs_datapath}/gdas.${yearprev}${monprev}${dayprev}/${hourprev}/gdas.t${hourprev}z.snogrb_t1534.3072.1536
nrecs_snow=`$WGRIB ${fnsnoa} | grep -i $snoid | wc -l`
if [ $nrecs_snow -eq 0 ]; then
   # no snow depth in file, use model
   fnsnoa=' ' # no input file
   export FSNOL=99999 # use model value
   echo "no snow depth in snow analysis file, use model"
else
   # snow depth in file, but is it current?
   if [ `$WGRIB -4yr ${fnsnoa} 2>/dev/null|grep -i $snoid |\
         awk -F: '{print $3}'|awk -F= '{print $2}'` -le \
        `$WGRIB -4yr ${fnsnog} 2>/dev/null|grep -i $snoid  |\
         awk -F: '{print $3}'|awk -F= '{print $2}'` ] ; then
      echo "no snow analysis, use model"
      fnsnoa=' ' # no input file
      export FSNOL=99999 # use model value
   else
      echo "current snow analysis found in snow analysis file, replace model"
      export FSNOL=0 # use analysis value
   fi
fi

ls -l 

FHRESTART=${FHRESTART:-$ANALINC}
if [ "${iau_delthrs}" != "-1" ]; then
   FHMAX_FCST=`expr $FHMAX + $ANALINC`
   FHSTOCH=`expr $FHRESTART + $ANALINC \/ 2`
   if [ "${fg_only}" == "true" ]; then
      FHSTOCH=${FHSTOCH:-$ANALINC}
      FHRESTART=`expr $ANALINC \/ 2`
      FHMAX_FCST=$FHMAX
   fi
else
   FHSTOCH=$FHRESTART
   FHMAX_FCST=$FHMAX
fi

if [ "$warm_start" == "T" ] && [ -z $skip_global_cycle ]; then
   # run global_cycle to update surface in restart file.
   export BASE_GSM=${fv3gfspath}
   export FIXfv3=$FIXFV3
   # global_cycle chokes for 3,9,15,18 UTC hours in CDATE
   #export CDATE="${year_start}${mon_start}${day_start}${hour_start}"
   export CDATE=${analdate}
   export CYCLEXEC=${execdir}/global_cycle
   export CYCLESH=${enkfscripts}/global_cycle.sh
   export COMIN=${PWD}/INPUT
   export COMOUT=$COMIN
   export FNTSFA="${fntsfa}"
   export FNSNOA="${fnsnoa}"
   export FNACNA="${fnacna}"
   export CASE="C${RES}"
   export PGM="${execdir}/global_cycle"
   if [ $NST_GSI -gt 0 ]; then
       export GSI_FILE=${datapath2}/${PREINP}dtfanl.nc
   fi
   sh ${enkfscripts}/global_cycle_driver.sh
   n=1
   while [ $n -le 6 ]; do
     ls -l ${COMOUT}/sfcanl_data.tile${n}.nc
     ls -l ${COMOUT}/sfc_data.tile${n}.nc
     if [ -s ${COMOUT}/sfcanl_data.tile${n}.nc ]; then
         /bin/mv -f ${COMOUT}/sfcanl_data.tile${n}.nc ${COMOUT}/sfc_data.tile${n}.nc
     else
         echo "global_cycle failed, exiting .."
         exit 1
     fi
     ls -l ${COMOUT}/sfc_data.tile${n}.nc
     n=$((n+1))
   done
   /bin/rm -rf rundir*
fi

# NSST Options
# nstf_name contains the NSST related parameters
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
# nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
# nstf_name(4) : ZSEA1 (in mm) : 0
# nstf_name(5) : ZSEA2 (in mm) : 0
# nst_anl      : .true. or .false., NSST analysis over lake
NST_MODEL=${NST_MODEL:-0}
NST_SPINUP=${NST_SPINUP:-0}
NST_RESV=${NST_RESV-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
nstf_name=${nstf_name:-"$NST_MODEL,$NST_SPINUP,$NST_RESV,$ZSEA1,$ZSEA2"}
nst_anl=${nst_anl:-".true."}
if [ $NST_GSI -gt 0 ] && [ $FHCYC -gt 0]; then
   fntsfa='        ' # no input file, use GSI foundation temp
   fnsnoa='        '
   fnacna='        '
fi

cat > model_configure <<EOF
print_esmf:              .true.
total_member:            1
PE_MEMBER01:             ${nprocs}
start_year:              ${year}
start_month:             ${mon}
start_day:               ${day}
start_hour:              ${hour}
start_minute:            0
start_second:            0
nhours_fcst:             ${FHMAX_FCST}
RUN_CONTINUE:            F
ENS_SPS:                 F
dt_atmos:                ${dt_atmos} 
output_1st_tstep_rst:    .false.
calendar:                'julian'
cpl:                     F
memuse_verbose:          F
atmos_nthreads:          ${OMP_NUM_THREADS}
use_hyper_thread:        F
ncores_per_node:         ${corespernode}
restart_interval:        ${FHRESTART}
quilting:                ${quilting}
write_groups:            ${write_groups}
write_tasks_per_group:   ${write_tasks}
num_files:               2
filename_base:           'dyn' 'phy'
output_grid:             'gaussian_grid'
output_file:             'netcdf'
nbits:                   14
ideflate:                1
write_fsyncflag:         .true.
write_nemsioflip:        .true.
iau_offset:              ${iaudelthrs}
imo:                     ${LONB}
jmo:                     ${LATB}
nfhout:                  ${FHOUT}
nfhmax_hf:               -1
nfhout_hf:               -1
nsout:                   -1
EOF
cat model_configure

# setup coupler.res (needed for restarts if current time != start time)
if [ "${iau_delthrs}" != "-1" ]  && [ "${fg_only}" == "false" ]; then
   echo "     2        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)" > INPUT/coupler.res
   echo "  ${year}  ${mon}  ${day}  ${hour}     0     0        Model start time:   year, month, day, hour, minute, second" >> INPUT/coupler.res
   echo "  ${year_start}  ${mon_start}  ${day_start}  ${hour_start}     0     0        Current model time: year, month, day, hour, minute, second" >> INPUT/coupler.res
   cat INPUT/coupler.res
else
   /bin/rm -f INPUT/coupler.res # assume current time == start time
fi

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
  fdiag = ${FHOUT}
/

&diag_manager_nml
  prepend_date = F,
/

&fms_io_nml
  checksum_required = F,
  max_files_r = 100,
  max_files_w = 100,
/

&mpp_io_nml
  shuffle=1,
  deflate_level=1,
/

&fms_nml
  clock_grain = "ROUTINE",
  domains_stack_size = 6000000,
  print_memory_usage = F,
/

&fv_core_nml
  external_eta = T, 
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
  n_sponge = 10,
  nudge_qv = T,
  nudge_dz = F,
  tau = 10.0,
  rf_cutoff = 750.0,
  d2_bg_k1 = 0.15,
  d2_bg_k2 = 0.02,
  d2_bg = 0.
  kord_tm = -9,
  kord_mt = 9,
  kord_wz = 9,
  kord_tr = 9,
  hydrostatic = ${hydrostatic},
  phys_hydrostatic = F,
  use_hydro_pressure = ${hydrostatic},
  beta = 0,
  a_imp = 1.0,
  p_fac = 0.1,
  k_split  = ${k_split:-2},
  n_split  = ${n_split:-6},
  nwat = ${nwat},
  na_init = ${na_init},
  d_ext = 0.0,
  dnats = ${dnats},
  fv_sg_adj = ${fv_sg_adj:-450},
  d2_bg = 0.0,
  nord = ${nord:-3},
  dddmp = ${dddmp:-0.2},
  d4_bg = ${d4_bg:-0.12},
  delt_max = 0.002,
  vtdm4 = ${vtdm4},
  ke_bg = 0.0,
  do_vort_damp = T,
  external_ic = $externalic,
  res_latlon_dynamics=$reslatlondynamics,
  read_increment=$readincrement,
  gfs_phil = F,
  agrid_vel_rst = F,
  nggps_ic = T,
  mountain = ${mountain},
  ncep_ic = F,
  d_con = 1.0,
  hord_mt = ${hord_mt},
  hord_vt = ${hord_vt},
  hord_tm = ${hord_tm},
  hord_dp = ${hord_dp},
  hord_tr = 8,
  adjust_dry_mass = T,
  do_sat_adj = ${do_sat_adj:-"F"},
  consv_am = F,
  fill = T,
  dwind_2d = F,
  print_freq = 6,
  warm_start = ${warm_start},
  no_dycore = F,
  z_tracer = T,
/

&external_ic_nml
  filtered_terrain = T,
  levp = $LEVP,
  gfs_dwinds = T,
  checker_tr = F,
  nt_checker = 0,
/

&gfs_physics_nml
  iccn           = F
  fhzero         = ${FHOUT}
  ldiag3d        = F
  fhcyc          = ${FHCYC}
  nst_anl        = ${nst_anl}
  use_ufo        = T
  pre_rad        = F
  ncld           = ${ncld}
  imp_physics    = ${imp_physics}
  pdfcld         = ${pdfcld:-"F"}
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
  cal_pre        = ${cal_pre:-"T"}
  redrag         = T
  dspheat        = ${dspheat:-"T"}
  hybedmf        = T
  random_clds    = ${random_clds:-"T"}
  trans_trac     = ${trans_trac:-"T"}
  cnvcld         = ${cnvcld:-"T"}
  imfshalcnv     = 2
  imfdeepcnv     = 2
  prslrd0        = 0
  ivegsrc        = 1
  isot           = 1
  debug          = T
  nstf_name      = 0
  lgfdlmprad     = ${lgfdlmprad:-"F"}
  effr_in        = ${effr_in:-"F"}
  cdmbgwd        = ${cdmbgwd}
  psautco        = ${psautco}
  prautco        = ${prautco}
  h2o_phys       = ${h2o_phys:-"T"}
  nstf_name      = ${nstf_name}
  nst_anl        = ${nst_anl}
  ldiag_ugwp   = .false.
  do_ugwp      = .false.
  do_skeb      = $DO_SKEB
  do_sppt      = $DO_SPPT
  do_shum      = $DO_SHUM
  iau_filter_increments = F
  iau_drymassfixer = F
  iaufhrs = ${iaufhrs}
  iau_delthrs = ${iaudelthrs}
  iau_inc_files = ${iau_inc_files}
/

&gfdl_cloud_microphysics_nml
  sedi_transport = .true.
  do_sedi_heat = .false.
  rad_snow = .true.
  rad_graupel = .true.
  rad_rain = .true.
  const_vi = .F.
  const_vs = .F.
  const_vg = .F.
  const_vr = .F.
  vi_max = 1.
  vs_max = 2.
  vg_max = 12.
  vr_max = 12.
  qi_lim = 1.
  prog_ccn = .false.
  do_qa = .true.
  fast_sat_adj = .true.
  tau_l2v = 225.
  tau_v2l = 150.
  tau_g2v = 900.
  rthresh = 10.e-6  ! This is a key parameter for cloud water
  dw_land  = 0.16
  dw_ocean = 0.10
  ql_gen = 1.0e-3
  ql_mlt = 1.0e-3
  qi0_crt = 8.0E-5
  qs0_crt = 1.0e-3
  tau_i2s = 1000.
  c_psaci = 0.05
  c_pgacs = 0.01
  rh_inc = 0.30
  rh_inr = 0.30
  rh_ins = 0.30
  ccn_l = 300.
  ccn_o = 100.
  c_paut = 0.5
  c_cracw = 0.8
  use_ppm = .false.
  use_ccn = .true.
  mono_prof = .true.
  z_slope_liq  = .true.
  z_slope_ice  = .true.
  de_ice = .false.
  fix_negative = .true.
  icloud_f = 1
  mp_time = 150.
/

&cires_ugwp_nml
       knob_ugwp_solver  = 2
       knob_ugwp_source  = 1,1,0,0
       knob_ugwp_wvspec  = 1,25,25,25
       knob_ugwp_azdir   = 2,4,4,4
       knob_ugwp_stoch   = 0,0,0,0
       knob_ugwp_effac   = 1,1,1,1
       knob_ugwp_doaxyz  = 1
       knob_ugwp_doheat  = 1
       knob_ugwp_dokdis  = 1
       knob_ugwp_ndx4lh  = 1
       knob_ugwp_version = 0
       launch_level      = 54
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
  FTSFS = 90,
  FAISL = 99999,
  FAISS = 99999,
  FSNOL = 99999,
  FSNOS = 99999,
  FSICL = 99999,
  FSICS = 99999,
  FTSFL = 99999,
  FVETL = 99999,
  FSOTL = 99999,
  FvmnL = 99999,
  FvmxL = 99999,
  FSLPL = 99999,
  FABSL = 99999,
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
  SKEB_NPASS=$SKEB_NPASS,
  SKEBINT=$SKEBINT,
  ISEED_SPPT=$ISEED_SPPT,ISEED_SHUM=$ISEED_SHUM,ISEED_SKEB=$ISEED_SKEB,
  use_zmtnblck=.true.,fhstoch=$FHSTOCH,stochini=$stochini,new_lscale=.true.
/

&nam_sfcperts
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
${enkfscripts}/runmpi
if [ $? -ne 0 ]; then
   echo "model failed..."
   exit 1
else
   echo "done running model.. `date`"
fi

# rename netcdf files (if quilting = .true.).
export DATOUT=${DATOUT:-$datapathp1}
if [ "$quilting" == ".true." ]; then
   ls -l dyn*.nc
   ls -l phy*.nc
   fh=$FHMIN
   while [ $fh -le $FHMAX ]; do
     charfhr="fhr"`printf %02i $fh`
     charfhr2="f"`printf %03i $fh`
     /bin/mv -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
     if [ $? -ne 0 ]; then
        echo "netcdffile missing..."
        exit 1
     fi
     /bin/mv -f phy${charfhr2}.nc ${DATOUT}/bfg_${analdatep1}_${charfhr}_${charnanal}
     if [ $? -ne 0 ]; then
        echo "netcdf file missing..."
        exit 1
     fi
     fh=$[$fh+$FHOUT]
   done
fi

ls -l *nc
if [ -z $dont_copy_restart ]; then # if dont_copy_restart not set, do this
   ls -l RESTART
   # copy restart file to INPUT directory for next analysis time.
   /bin/rm -rf ${datapathp1}/${charnanal}/RESTART ${datapathp1}/${charnanal}/INPUT
   mkdir -p ${datapathp1}/${charnanal}/INPUT
   cd RESTART
   ls -l
   datestring="${yrnext}${monnext}${daynext}.${hrnext}0000."
   for file in ${datestring}*nc; do
      file2=`echo $file | cut -f3-10 -d"."`
      /bin/mv -f $file ${datapathp1}/${charnanal}/INPUT/$file2
      if [ $? -ne 0 ]; then
        echo "restart file missing..."
        exit 1
      fi
      done
   cd ..
fi

# also move history files if copy_history_files is set.
if [ ! -z $copy_history_files ]; then
  mkdir -p ${DATOUT}/${charnanal}
  /bin/mv -f fv3_historyp*.nc ${DATOUT}/${charnanal}
  # copy with compression
  #n=1
  #while [ $n -le 6 ]; do
  #   # lossless compression
  #   ncks -4 -L 5 -O fv3_historyp.tile${n}.nc ${DATOUT}/${charnanal}/fv3_historyp.tile${n}.nc
  #   # lossy compression
  #   #ncks -4 --ppc default=5 -O fv3_history.tile${n}.nc ${DATOUT}/${charnanal}/fv3_history.tile${n}.nc
  #   /bin/rm -f fv3_historyp.tile${n}.nc
  #   n=$((n+1))
  #done
fi

# if random pattern restart file exists for end of IAU window, copy it.
ls -l stoch_out*
charfh="F"`printf %06i $FHSTOCH`
if [ -s stoch_out.${charfh} ]; then
  mkdir -p ${DATOUT}/${charnanal}
  echo "copying stoch_out.${charfh} ${DATOUT}/${charnanal}/stoch_ini"
  /bin/mv -f "stoch_out.${charfh}" ${DATOUT}/${charnanal}/stoch_ini
fi

ls -l ${DATOUT}
ls -l ${datapathp1}/${charnanal}/INPUT

# remove symlinks from INPUT directory
cd INPUT
find -type l -delete
cd ..
/bin/rm -rf RESTART # don't need RESTART dir anymore.

echo "all done at `date`"

exit 0
