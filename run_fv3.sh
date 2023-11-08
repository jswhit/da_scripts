#!/bin/sh
# model was compiled with these 
echo "starting at `date`"

export VERBOSE=${VERBOSE:-"NO"}
hydrostatic=${hydrostatic:=".false."}
launch_level=$(echo "$LEVS/2.35" |bc)
if [ $VERBOSE = "YES" ]; then
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
# yr,mon,day,hr at middle of assim window (analysis time)
export yeara=`echo $analdate |cut -c 1-4`
export mona=`echo $analdate |cut -c 5-6`
export daya=`echo $analdate |cut -c 7-8`
export houra=`echo $analdate |cut -c 9-10`
export yearprev=`echo $analdatem1 |cut -c 1-4`
export monprev=`echo $analdatem1 |cut -c 5-6`
export dayprev=`echo $analdatem1 |cut -c 7-8`
export hourprev=`echo $analdatem1 |cut -c 9-10`
#analdatep1m3=`$incdate $analdatep1 -3`
if [ "${iau_delthrs}" != "-1" ] && [ "${cold_start}" == "false" ]; then
# assume model is started at beginning of analysis window
# (if IAU on or initial cold start)
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
   export yrp3=`echo $analdatep1m3 |cut -c 1-4`
   export monp3=`echo $analdatep1m3 |cut -c 5-6`
   export dayp3=`echo $analdatep1m3 |cut -c 7-8`
   export hrp3=`echo $analdatep1m3 |cut -c 9-10`
   # time for restart file
   if [ "${iau_delthrs}" != "-1" ] ; then
      # beginning of next analysis window
      export yrnext=$yrp3
      export monnext=$monp3
      export daynext=$dayp3
      export hrnext=$hrp3
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
/bin/rm -f dyn* phy* *nemsio* PET*
export DIAG_TABLE=${DIAG_TABLE:-$enkfscripts/diag_table}
/bin/cp -f $DIAG_TABLE diag_table
/bin/cp -f $enkfscripts/nems.configure .
/bin/cp -f $enkfscripts/fd_nems.yaml .
# insert correct starting time and output interval in diag_table template.
sed -i -e "s/YYYY MM DD HH/${year} ${mon} ${day} ${hour}/g" diag_table
sed -i -e "s/FHOUT/${RESTART_FREQ}/g" diag_table
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
   iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
# IAU - multiple increments.
   for fh in $iaufhrs2; do
      export increment_file="fv3_increment${fh}.nc"
      if [ $charnanal == "control" ] && [ "$replay_controlfcst" == 'true' ]; then
         export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_ensmean"
         export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}.chgres"
      else
         export analfile="${datapath2}/sanl_${analdate}_fhr0${fh}_${charnanal}"
         export fgfile="${datapath2}/sfg_${analdate}_fhr0${fh}_${charnanal}"
      fi
   cat > calc_increment_ncio.nml << EOF
&setup
   no_mpinc=.true.
   no_delzinc=.false.
   taper_strat=.true.
   taper_strat_ozone=.false.
   taper_pbl=.false.
   ak_bot=10000.,
   ak_top=5000.
/
EOF
      cat calc_increment_ncio.nml
      echo "create ${increment_file}"
      /bin/rm -f ${increment_file}
      export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file}"
      nprocs=1 mpitaskspernode=1 ${enkfscripts}/runmpi
      if [ $? -ne 0 -o ! -s ${increment_file} ]; then
         echo "problem creating ${increment_file}, stopping .."
         exit 1
      fi
      #echo "create ${increment_file}"
      #/bin/rm -f ${increment_file}
      ## last three args:  no_mpinc no_delzinc, taper_strat
      #export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file} T $hydrostatic T"
      #nprocs=1 mpitaskspernode=1 ${enkfscripts}/runmpi
      #if [ $? -ne 0 -o ! -s ${increment_file} ]; then
      #   echo "problem creating ${increment_file}, stopping .."
      #   exit 1
      #fi
   done # do next forecast
   cd ..
else
   if [ $cold_start == "false" ] ; then
      cd INPUT
      iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
# move already computed increment files
      for fh in $iaufhrs2; do
         export increment_file="fv3_increment${fh}.nc"
         /bin/mv -f ${datapath2}/incr_${analdate}_fhr0${fh}_${charnanal} ${increment_file}
      done
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
   iaudelthrs=-1
   #iau_inc_files="fv3_increment.nc"
   iau_inc_files=""
   warm_start=F
   externalic=T
   mountain=F
else
   warm_start=T
   externalic=F
   mountain=T
   # warm start from restart file with lat/lon increments ingested by the model
   if [ -s INPUT/atm_stoch.res.nc ]; then
      echo "stoch_ini available, setting stochini=T"
      stochini=T # restart random patterns from existing file
   else
      echo "stoch_ini not available, setting stochini=F"
      stochini=F
   fi
   
   iaudelthrs=${iau_delthrs}
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

# halve time step if niter>1 and niter==nitermax
if [[ $niter -gt 1 ]] && [[ $niter -eq $nitermax ]]; then
    dt_atmos=`python -c "print(${dt_atmos}/2)"`
    stochini=F
    echo "dt_atmos changed to $dt_atmos..."
    #DO_SKEB=F
    #DO_SPPT=F
    #DO_SHUM=F
fi

snoid='SNOD'

# Turn off snow analysis if it has already been used.
# (snow analysis only available once per day at 18z)
fntsfa=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/atmos/${RUN}.t${houra}z.rtgssthr.grb
fnacna=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/atmos/${RUN}.t${houra}z.seaice.5min.grb
fnsnoa=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/atmos/${RUN}.t${houra}z.snogrb_t1534.3072.1536
fnsnog=${obs_datapath}/${RUN}.${yearprev}${monprev}${dayprev}/${hourprev}/atmos/${RUN}.t${hourprev}z.snogrb_t1534.3072.1536
nrecs_snow=`$WGRIB ${fnsnoa} | grep -i $snoid | wc -l`
#nrecs_snow=0 # force no snow update (do this if NOAH-MP used)
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

if [ $nanals2 -gt 0 ] && [ $nmem -le $nanals2 ]; then
   longer_fcst="YES"
   # if longfcst_singletime=0, FHMAX_LONGER is divisible by 6, and only a single forecast time
   # (the end of the forecast) beyond FHMAX is saved.  If longfcst_singletime=3, then it is 
   # assumed that all the times in the 6-h window centered on FHMAX_LONGER - 3 are desired so
   # that the GSI observer can be run.
   longfcst_singletime=`python -c "from __future__ import print_function; print($FHMAX_LONGER % 6)"`
   echo "longfcst_singletime=$longfcst_singletime"
else
   longer_fcst="NO"
fi
if [ "${iau_delthrs}" != "-1" ]; then
   if [ $longer_fcst = "YES" ]; then
      FHMAX_FCST=`expr $FHMAX_LONGER + $ANALINC`
   else
      FHMAX_FCST=`expr $FHMAX + $ANALINC`
   fi
   if [ ${cold_start} = "true" ]; then
      if [ $longer_fcst = "YES" ]; then
         FHMAX_FCST=$FHMAX_LONGER
      else
         FHMAX_FCST=$FHMAX
      fi
   fi
else
   if [ $longer_fcst = "YES" ]; then
      FHMAX_FCST=$FHMAX_LONGER
   else
      FHMAX_FCST=$FHMAX
   fi
fi

if [ $FHCYC -gt 0 ]; then
  skip_global_cycle=1
fi

if [ $cold_start = "false" ] && [ -z $skip_global_cycle ]; then
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
if [ $cold_start = "true" ] && [ $NST_GSI -gt 0 ]; then
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
export timestep_hrs=`python -c "from __future__ import print_function; print($dt_atmos / 3600.)"`
if [ "${iau_delthrs}" != "-1" ]  && [ "${cold_start}" == "false" ]; then
   FHROT=3
else
   if [ $cold_start == "true" ] && [ $analdate -gt 2021032400 ]; then
     FHROT=3
   else
     FHROT=0
   fi
fi
if [ $cold_start == "true" ] && [ $analdate -gt 2021032400 ] && [ "${iau_delthrs}" != "-1" ]; then
   # cold start ICS at end of window, need one timestep restart
   restart_interval=`python -c "from __future__ import print_function; print($FHROT + $timestep_hrs)"`
   output_1st_tstep_rst=".true."
else
   restart_interval="$RESTART_FREQ -1"
   output_1st_tstep_rst=".false."
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
fhrot:                   ${FHROT}
RUN_CONTINUE:            F
ENS_SPS:                 F
dt_atmos:                ${dt_atmos} 
output_1st_tstep_rst:    ${output_1st_tstep_rst}
calendar:                'julian'
cpl:                     F
memuse_verbose:          F
atmos_nthreads:          ${OMP_NUM_THREADS}
use_hyper_thread:        F
ncores_per_node:         ${corespernode}
restart_interval:        ${restart_interval}
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
write_nsflip:            .true.
iau_offset:              ${iaudelthrs}
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
sed -i -e "s/SUITE/${SUITE}/g" input.nml
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
sed -i -e "s/FHOUT/${FHOUT}/g" input.nml
sed -i -e "s/CDMBGWD/${cdmbgwd}/g" input.nml
sed -i -e "s/ISEED_sppt/${ISEED_SPPT}/g" input.nml
sed -i -e "s/ISEED_shum/${ISEED_SHUM}/g" input.nml
sed -i -e "s/ISEED_skeb/${ISEED_SKEB}/g" input.nml
sed -i -e "s/IAU_FHRS/${iaufhrs}/g" input.nml
sed -i -e "s/IAU_DELTHRS/${iaudelthrs}/g" input.nml
sed -i -e "s/IAU_INC_FILES/${iau_inc_files}/g" input.nml
sed -i -e "s/WARM_START/${warm_start}/g" input.nml
sed -i -e "s/EXTERNAL_IC/${externalic}/g" input.nml
sed -i -e "s/MOUNTAIN/${mountain}/g" input.nml
sed -i -e "s/RESLATLONDYNAMICS/${reslatlondynamics}/g" input.nml
sed -i -e "s/READ_INCREMENT/${readincrement}/g" input.nml
sed -i -e "s/HYDROSTATIC/${hydrostatic}/g" input.nml
sed -i -e "s/LAUNCH_LEVEL/${launch_level}/g" input.nml
sed -i -e "s/FHCYC/${FHCYC}/g" input.nml
sed -i -e "s!FIXDIR!${FIXDIR_gcyc}!g" input.nml
sed -i -e "s!SSTFILE!${fntsfa}!g" input.nml
sed -i -e "s!ICEFILE!${fnacna}!g" input.nml
sed -i -e "s!SNOFILE!${fnsnoa}!g" input.nml
sed -i -e "s/FSNOL_PARM/${FSNOL}/g" input.nml
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

export DATOUT=${DATOUT:-$datapathp1}
# this is a hack to work around the fact that first time step history
# file is not written if restart file requested at first time step.
if [ $cold_start == "true" ] && [ $analdate -gt 2021032400 ]; then
   if [ ! -s  dynf003.nc ]; then
     echo "dynf003.nc missing, copy dynf004"
     /bin/cp -f dynf004.nc dynf003.nc
   fi
   if [ ! -s  phyf003.nc ]; then
     echo "phyf003.nc missing, copy phyf004"
     /bin/cp -f phyf004.nc phyf003.nc
   fi
fi
# rename netcdf history files.
ls -l dyn*.nc
ls -l phy*.nc
fh=$FHMIN
while [ $fh -le $FHMAX ]; do
  charfhr="fhr"`printf %02i $fh`
  charfhr2="f"`printf %03i $fh`
  if [ $longer_fcst = "YES" ] && [ $fh -eq $FHMAX ] && [ $longfcst_singletime -gt 0 ]; then
     # copy file, it will be duplicated as sfg2
     /bin/cp -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
  else
     /bin/mv -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
  fi
  if [ $? -ne 0 ]; then
     echo "netcdffile missing..."
     exit 1
  fi
  if [ $longer_fcst = "YES" ] && [ $fh -eq $FHMAX ] && [ $longfcst_singletime -gt 0 ]; then
     # copy file, it will be duplicated as bfg2
     /bin/cp -f phy${charfhr2}.nc ${DATOUT}/bfg_${analdatep1}_${charfhr}_${charnanal}
  else
     /bin/mv -f phy${charfhr2}.nc ${DATOUT}/bfg_${analdatep1}_${charfhr}_${charnanal}
  fi
  if [ $? -ne 0 ]; then
     echo "netcdf file missing..."
     exit 1
  fi
  fh=$[$fh+$FHOUT]
done
if [ $longer_fcst = "YES" ]; then
    if [ $longfcst_singletime -eq 0 ]; then
       # save just the last file (to compare with IFS analysis in grid space, no time interp
       # needed for GSI observer)
       analdatep2=`$incdate $analdate $FHMAX_LONGER`
       mkdir -p $datapath/$analdatep2
       charfhr="fhr"`printf %02i $FHMAX_LONGER`
       charfhr2="f"`printf %03i $FHMAX_LONGER`
       /bin/mv -f dyn${charfhr2}.nc ${datapath}/${analdatep2}/sfg2_${analdatep2}_${charfhr}_${charnanal}
       /bin/mv -f phy${charfhr2}.nc ${datapath}/${analdatep2}/bfg2_${analdatep2}_${charfhr}_${charnanal}
    else
       fh=`expr $FHMAX_LONGER - $ANALINC`
       fhmax2=`expr $FHMAX_LONGER - $ANALINC \/ 2`
       analdatep2=`$incdate $analdate $fhmax2`
       mkdir -p $datapath/$analdatep2
       while [ $fh -le $FHMAX_LONGER ]; do
         charfhr="fhr"`printf %02i $fh`
         charfhr2="f"`printf %03i $fh`
         /bin/mv -f dyn${charfhr2}.nc ${datapath}/${analdatep2}/sfg2_${analdatep2}_${charfhr}_${charnanal}
         if [ $? -ne 0 ]; then
            echo "netcdffile missing..."
            exit 1
         fi
         /bin/mv -f phy${charfhr2}.nc ${datapath}/${analdatep2}/bfg2_${analdatep2}_${charfhr}_${charnanal}
         if [ $? -ne 0 ]; then
            echo "netcdf file missing..."
            exit 1
         fi
         fh=$[$fh+$FHOUT]
       done
    fi
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
   datestring="${yrnext}${monnext}${daynext}.${hrnext}"
   for file in ${datestring}*nc; do
      file2=`echo $file | cut -f3-10 -d"."`
      /bin/mv -f $file ${datapathp1}/${charnanal}/INPUT/$file2
      if [ $? -ne 0 ]; then
        echo "restart file missing..."
        exit 1
      fi
   done
   if [ -s  ${datapathp1}/${charnanal}/INPUT/ca_data.tile1.nc ]; then
      touch ${datapathp1}/${charnanal}/INPUT/ca_data.nc
   fi
   cd ..
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
