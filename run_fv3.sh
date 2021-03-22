#!/bin/sh
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh

use_ipd=${use_ipd:-"NO"}
if [ "$machine" == 'hera' ]; then
   module purge
   module use /scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack/v1.0.0-beta1/modulefiles/stack
   module load hpc/1.0.0-beta1
   module load hpc-intel/18.0.5.274
   module load hpc-impi/2018.0.4
   module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   module load netcdf_parallel/4.7.4.release
   module load esmf/8.1.0bs25_ParallelNetCDF.release
   module load hdf5_parallel/1.10.6.release
   module load wgrib
   export WGRIB=`which wgrib`
elif [ "$machine" == 'orion' ]; then
   module purge
   module use /apps/contrib/NCEP/libs/hpc-stack/v1.0.0-beta1/modulefiles/stack
   module load hpc/1.0.0-beta1
   module load hpc-intel/2018.4
   module load hpc-impi/2018.4
   module load hdf5/1.10.6
   module load netcdf/4.7.4
   module load pio/2.5.1
   module load esmf/8_1_0_beta_snapshot_27
   module load wgrib
   export WGRIB=`which wgrib`
elif [ "$machine" == 'gaea' ]; then
   module purge
   module load PrgEnv-intel/6.0.3
   module rm intel
   module load intel/18.0.3.222
   #module load cray-netcdf-hdf5parallel/4.6.1.3
   #module load cray-hdf5-parallel/1.10.2.0
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
hydrostatic=${hydrostatic:=".false."}
launch_level=$(echo "$LEVS/2.35" |bc)
if [ "$VERBOSE" == "YES" ]; then
 set -x
fi

ulimit -s unlimited

niter=${niter:-1}
if [ "$charnanal" != "control" ] && [ "$charnanal" != "ensmean" ]; then
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

export year=`echo $analdate |cut -c 1-4`
export mon=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`

analdatem6=`$incdate $analdate -6`
# used to to test for new snow analysis
export yearprev=`echo $analdatem6 |cut -c 1-4`
export monprev=`echo $analdatem6 |cut -c 5-6`
export dayprev=`echo $analdatem6 |cut -c 7-8`
export hourprev=`echo $analdatem6 |cut -c 9-10`
# time for restart to initialize next background forecast
if [ $cold_start == "true" ]; then # cold start
   analdatep1=`$incdate $analdate 6`
else
   analdatep1=`$incdate $analdate 1`
fi
export yrnext=`echo $analdatep1 |cut -c 1-4`
export monnext=`echo $analdatep1 |cut -c 5-6`
export daynext=`echo $analdatep1 |cut -c 7-8`
export hrnext=`echo $analdatep1 |cut -c 9-10`

# copy data, diag and field tables.
cd ${datapath2}/${charnanal}
if [ $? -ne 0 ]; then
  echo "cd to ${datapath2}/${charnanal} failed, stopping..."
  exit 1
fi
/bin/rm -f dyn* phy* *nemsio* PET*
export DIAG_TABLE=${DIAG_TABLE:-$enkfscripts/diag_table}
/bin/cp -f $DIAG_TABLE diag_table
/bin/cp -f $enkfscripts/nems.configure .
# insert correct starting time and output interval in diag_table template.
sed -i -e "s/YYYY MM DD HH/${year} ${mon} ${day} ${hour}/g" diag_table
sed -i -e "s/FHOUT/${FHOUT}/g" diag_table
/bin/cp -f $enkfscripts/field_table_${SUITE} field_table
/bin/cp -f $enkfscripts/data_table . 
/bin/rm -rf RESTART
mkdir -p RESTART
mkdir -p INPUT

# make symlinks for fixed files and initial conditions.
cd INPUT
if [ "$cold_start" == "true" ]; then
   ls -l *nc
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
# for Thompson microphysics
#ln -fs $FIXGLOBAL/CCN_ACTIVATE.BIN CCN_ACTIVATE.BIN
#ln -fs $FIXGLOBAL/freezeH2O.dat freezeH2O.dat

# create netcdf increment files.
if [ "$cold_start" == "false" ] && [ -z $skip_calc_increment ]; then
   cd INPUT
   fh=6
   export increment_file="fv3_increment${fh}.nc"
   if [ $charnanal == "control" ] && [ "$replay_controlfcst" == 'true' ]; then
      export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_ensmean"
      export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}.chgres"
   else
      export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_${charnanal}"
      export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}"
   fi
   echo "create ${increment_file}"
   /bin/rm -f ${increment_file}
   # last three args:  no_mpinc no_delzinc, taper_strat (humidity increment)
   export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file} T $hydrostatic T"
   nprocs=1 mpitaskspernode=1 ${enkfscripts}/runmpi
   if [ $? -ne 0 -o ! -s ${increment_file} ]; then
      echo "problem creating ${increment_file}, stopping .."
      exit 1
   fi
   cd ..
else
   if [ $cold_start == "false" ] ; then
      cd INPUT
      export increment_file="fv3_increment${fh}.nc"
      /bin/mv -f ${datapath2}/incr_${analdate}_fhr06_{charnanal} ${increment_file}
      cd ..
   fi
fi

# setup model namelist parameters
if [ "$cold_start" == "true" ]; then
   # cold start from chgres'd GFS analyes
   stochini=F
   reslatlondynamics=""
   readincrement=F
   FHCYC=0
   warm_start=F
   externalic=T
   mountain=F
else
   warm_start=T
   externalic=F
   mountain=T
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
   fi
   
   FHCYC=${FHCYC}
   reslatlondynamics="fv3_increment6.nc"
   readincrement=T
fi

snoid='SNOD'

# Turn off snow analysis if it has already been used.
# (snow analysis only available once per day at 18z)
fntsfa=${obs_datapath2}/${RUN}.${year}${mon}${day}/${hour}/${RUN}.t${hour}z.rtgssthr.grb
fnacna=${obs_datapath2}/${RUN}.${year}${mon}${day}/${hour}/${RUN}.t${hour}z.seaice.5min.grb
fnsnoa=${obs_datapath2}/${RUN}.${year}${mon}${day}/${hour}/${RUN}.t${hour}z.snogrb_t1534.3072.1536
fnsnog=${obs_datapath2}/${RUN}.${yearprev}${monprev}${dayprev}/${hourprev}/${RUN}.t${hourprev}z.snogrb_t1534.3072.1536
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
      export FSNOL=-2 # use analysis value
   fi
fi

ls -l 

FHRESTART=$FHOFFSET
FHSTOCH=$FHOFFSET # half of window length (set in main.sh)3
if [ $nanals2 -gt 0 ] && [ $nmem -le $nanals2 ]; then
   FHMAX_FCST=$FHMAX_LONGER
   longer_fcst="YES"
else
   if [ "$charnanal" == "control" ] && [ $cold_start != "true" ]; then
      FHMAX_FCST=2
   else
      FHMAX_FCST=$FHMAX
   fi
   longer_fcst="NO"
fi

if [ "$cold_start" == "false" ] && [ -z $skip_global_cycle ]; then
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
NST_MODEL=${NST_MODEL:-0}
NST_SPINUP=${NST_SPINUP:-0}
if [ "$cold_start" == "true" ] && [ $NST_GSI -gt 0 ]; then
   NST_SPINUP=1
fi
NST_RESV=${NST_RESV-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
nstf_name=${nstf_name:-"$NST_MODEL,$NST_SPINUP,$NST_RESV,$ZSEA1,$ZSEA2"}
if [ $NST_GSI -gt 0 ] && [ $FHCYC -gt 0 ]; then
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
output_1st_tstep_rst:    .true.
calendar:                'julian'
cpl:                     F
memuse_verbose:          F
atmos_nthreads:          ${OMP_NUM_THREADS}
use_hyper_thread:        F
ncores_per_node:         ${corespernode}
restart_interval:        ${FHRESTART}
quilting:                .true.
write_groups:            ${write_groups}
write_tasks_per_group:   ${write_tasks}
num_files:               2
filename_base:           'dyn' 'phy'
output_grid:             'gaussian_grid'
output_file:             'netcdf_parallel' 'netcdf'
nbits:                   14
ideflate:                1
ichunk2d:                ${LONB}
jchunk2d:                ${LATB}
ichunk3d:                0
jchunk3d:                0
kchunk3d:                0
write_nemsioflip:        .true.
write_fsyncflag:         .true.
iau_offset:              -1
imo:                     ${LONB}
jmo:                     ${LATB}
nfhout:                  ${FHOUT}
nfhmax_hf:               -1
nfhout_hf:               -1
nsout:                   -1
EOF
cat model_configure

# copy template namelist file, replace variables.
/bin/cp -f ${enkfscripts}/${SUITE}.nml input.nml
if [ $use_ipd = "YES" ]; then
    sed -i -e '/SUITE/d' input.nml
    sed -i -e '/oz_phys/d' input.nml
else
    sed -i -e "s/SUITE/${SUITE}/g" input.nml
fi
sed -i -e "s/LAYOUT/${layout}/g" input.nml
sed -i -e "s/NSTF_NAME/${nstf_name}/g" input.nml
sed -i -e "s/NPX/${npx}/g" input.nml
sed -i -e "s/NPY/${npx}/g" input.nml
sed -i -e "s/LEVP/${LEVP}/g" input.nml
sed -i -e "s/LEVS/${LEVS}/g" input.nml
sed -i -e "s/LONB/${LONB}/g" input.nml
sed -i -e "s/LATB/${LATB}/g" input.nml
sed -i -e "s/JCAP/${JCAP}/g" input.nml
sed -i -e "s/SPPT/${SPPT}/g" input.nml
sed -i -e "s/DO_sppt/${DO_SPPT}/g" input.nml
sed -i -e "s/SHUM/${SHUM}/g" input.nml
sed -i -e "s/DO_shum/${DO_SHUM}/g" input.nml
sed -i -e "s/SKEB/${SKEB}/g" input.nml
sed -i -e "s/DO_skeb/${DO_SKEB}/g" input.nml
sed -i -e "s/STOCHINI/${stochini}/g" input.nml
sed -i -e "s/FHSTOCH/${FHSTOCH}/g" input.nml
sed -i -e "s/FHOUT/${FHOUT}/g" input.nml
sed -i -e "s/CDMBGWD/${cdmbgwd}/g" input.nml
sed -i -e "s/ISEED_sppt/${ISEED_SPPT}/g" input.nml
sed -i -e "s/ISEED_shum/${ISEED_SHUM}/g" input.nml
sed -i -e "s/ISEED_skeb/${ISEED_SKEB}/g" input.nml
sed -i -e "s/WARM_START/${warm_start}/g" input.nml
sed -i -e "s/EXTERNAL_IC/${externalic}/g" input.nml
sed -i -e "s/MOUNTAIN/${mountain}/g" input.nml
sed -i -e "s/RESLATLONDYNAMICS/${reslatlondynamics}/g" input.nml
sed -i -e "s/READ_INCREMENT/${readincrement}/g" input.nml
sed -i -e "s/HYDROSTATIC/${hydrostatic}/g" input.nml
sed -i -e "s/LAUNCH_LEVEL/${launch_level}/g" input.nml
cat input.nml
ls -l INPUT

# run model
export PGM=$FCSTEXEC
ldd $FCSTEXEC
echo "start running model `date`"
${enkfscripts}/runmpi
if [ $? -ne 0 ]; then
   echo "model failed..."
   exit 1
else
   echo "done running model.. `date`"
fi

# rename netcdf files.
export DATOUT=${DATOUT:-$datapathp1}
ls -l dyn*.nc
ls -l phy*.nc
analdatep2=`$incdate $analdatep1 3`
mkdir -p $datapath/$analdatep2
fh=$FHMIN
while [ $fh -le $FHMAX_FCST ]; do
  if [ $cold_start == "true" ]; then
      charfhr="fhr"`printf %02i $fh`
  else
      fhx=`expr $fh + 5`
      charfhr="fhr"`printf %02i $fhx`
  fi
  charfhr2="f"`printf %03i $fh`
  if [ $longer_fcst = "YES" ] && [ $fh -ge 1 ] ; then
     fh3=`expr $fh + 2`
     charfhr3="fhr"`printf %02i $fh3`
     /bin/cp -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
     /bin/cp -f dyn${charfhr2}.nc ${datapath}/${analdatep2}/sfg2_${analdatep2}_${charfhr3}_${charnanal}
     /bin/cp -f phy${charfhr2}.nc ${DATOUT}/bfg_${analdatep1}_${charfhr}_${charnanal}
     /bin/cp -f phy${charfhr2}.nc ${datapath}/${analdatep2}/bfg2_${analdatep2}_${charfhr3}_${charnanal}
  else
     /bin/mv -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
     /bin/mv -f phy${charfhr2}.nc ${DATOUT}/bfg_${analdatep1}_${charfhr}_${charnanal}
  fi
  if [ $? -ne 0 ]; then
     echo "netcdf file missing..."
     exit 1
  fi
  fh=$[$fh+$FHOUT]
done
if [ $longer_fcst = "YES" ]; then
    fh=`expr $FHMAX + 1`
    while [ $fh -le $FHMAX_LONGER ]; do
      fhx=`expr $fh + 2`
      charfhr="f"`printf %03i $fhx`
      charfhr2="f"`printf %03i $fh`
      /bin/mv -f dyn${charfhr2}.nc ${datapath}/${analdatep2}/sfg2_${analdatep2}_${charfhr}_${charnanal}
      /bin/mv -f phy${charfhr2}.nc ${datapath}/${analdatep2}/bfg2_${analdatep2}_${charfhr}_${charnanal}
      if [ $? -ne 0 ]; then
         echo "netcdf file missing..."
         exit 1
      fi
      fh=$[$fh+$FHOUT]
    done
fi
/bin/rm -f phy*nc dyn*nc

ls -l *tile*nc
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

# if random pattern restart file exists, copy it.
ls -l stoch_out*
if [ $cold_start == "true" ]; then
  fhr = 1
else
  fhr = 6
fi
charfh="F"`printf %06i $fhr`
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
