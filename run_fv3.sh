#!/bin/sh
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh

export VERBOSE=${VERBOSE:-"NO"}
if [ $VERBOSE = "YES" ]; then
 set -x
fi

if [ $FHCYC -gt 0 ]; then
  skip_global_cycle=1
fi

if [ "$cold_start" == "true" ] || [ "${iau_delthrs}" == "-1" ]; then
   FHROT=0
else
   FHROT=3
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
export ISEED_CA=$((analdate+nmem))
export ISEED_SPPT=$((analdate*1000 + nmem*10))
export ISEED_SKEB=$((analdate*1000 + nmem*10 + 1))
export ISEED_SHUM=$((analdate*1000 + nmem*10 + 2))
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
sed -i -e "s/FHOUT/${FHOUT}/g" diag_table
/bin/cp -f $enkfscripts/field_table_${SUITE} field_table
/bin/cp -f $enkfscripts/data_table . 
/bin/rm -rf RESTART
mkdir -p RESTART
mkdir -p INPUT

# make symlinks for fixed files and initial conditions.
cd INPUT
if [ "$cold_start" == "true" ]; then
   for file in ../*nc; do
       file2=`basename $file`
       ln -fs $file $file2
   done
fi

# Grid and orography data
n=1
while [ $n -le 6 ]; do
 if [ $FRAC_GRID == ".true." ]; then
   ln -fs $FIXDIR/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/C${RES}_grid.tile${n}.nc    C${RES}_grid.tile${n}.nc
   ln -fs $FIXDIR/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/oro_C${RES}.${OCNRES}.tile${n}.nc oro_data.tile${n}.nc
 else
   ln -fs $FIXDIR/fix_fv3_gmted2010/C${RES}/C${RES}_grid.tile${n}.nc    C${RES}_grid.tile${n}.nc
   ln -fs $FIXDIR/fix_fv3_gmted2010/C${RES}/C${RES}_oro_data.tile${n}.nc  oro_data.tile${n}.nc
 fi
 ln -fs $FIXDIR/fix_ugwd/C${RES}/C${RES}_oro_data_ls.tile${n}.nc oro_data_ls.tile${n}.nc
 ln -fs $FIXDIR/fix_ugwd/C${RES}/C${RES}_oro_data_ss.tile${n}.nc oro_data_ss.tile${n}.nc
 n=$((n+1))
done
if [ $FRAC_GRID == ".true." ]; then
   ln -fs $FIXDIR/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/C${RES}_mosaic.nc  C${RES}_mosaic.nc
   ln -fs $FIXDIR/fix_cpl/aC${RES}o${ORES3}/grid_spec.nc  grid_spec.nc
else
   ln -fs $FIXDIR/fix_fv3_gmted2010/C${RES}/C${RES}_mosaic.nc  C${RES}_mosaic.nc
   ln -fs $FIXDIR/fix_fv3_gmted2010/C${RES}/C${RES}_mosaic.nc  grid_spec.nc
fi
cd ..
# new ozone and h2o physics for stratosphere
ln -fs $FIXDIR/fix_am/ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77 global_o3prdlos.f77
ln -fs $FIXDIR/fix_am/global_h2o_pltc.f77 global_h2oprdlos.f77 # used if h2o_phys=T
# co2, ozone, surface emiss and aerosol data.
ln -fs $FIXDIR/fix_am/global_solarconstant_noaa_an.txt solarconstant_noaa_an.txt
ln -fs $FIXDIR/fix_am/global_sfc_emissivity_idx.txt     sfc_emissivity_idx.txt
ln -fs $FIXDIR/fix_am/global_co2historicaldata_glob.txt co2historicaldata_glob.txt
ln -fs $FIXDIR/fix_am/co2monthlycyc.txt                 co2monthlycyc.txt
for file in `ls $FIXDIR/fix_am/global_co2historicaldata* ` ; do
   ln -fs $file $(echo $(basename $file) |sed -e "s/global_//g")
done
ln -fs $FIXDIR/fix_am/global_climaeropac_global.txt aerosol.dat
# for ugwpv1 and MERRA aerosol climo (IAER=1011)
ln -fs $FIXDIR/fix_ugwd/ugwp_limb_tau.nc ugwp_limb_tau.nc
for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
  ln -fs $FIXDIR/fix_aer/merra2.aerclim.2003-2014.m${n}.nc aeroclim.m${n}.nc
done
ln -fs  $FIXDIR/fix_lut/optics_BC.v1_3.dat  optics_BC.dat
ln -fs  $FIXDIR/fix_lut/optics_OC.v1_3.dat  optics_OC.dat
ln -fs  $FIXDIR/fix_lut/optics_DU.v15_3.dat optics_DU.dat
ln -fs  $FIXDIR/fix_lut/optics_SS.v3_3.dat  optics_SS.dat
ln -fs  $FIXDIR/fix_lut/optics_SU.v1_3.dat  optics_SU.dat
ls -l 

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
      echo "create ${increment_file}"
      /bin/rm -f ${increment_file}
      # last three args:  no_mpinc no_delzinc, taper_strat
      export "PGM=${execdir}/calc_increment_ncio.x ${fgfile} ${analfile} ${increment_file} T $hydrostatic T"
      nprocs=1 mpitaskspernode=1 ${enkfscripts}/runmpi
      if [ $? -ne 0 -o ! -s ${increment_file} ]; then
         echo "problem creating ${increment_file}, stopping .."
         exit 1
      fi
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
      echo "stoch restart available, setting stochini=T"
      stochini=T # restart random patterns from existing file
   else
      echo "stoch restart not available, setting stochini=F"
      stochini=F
   fi
   
   iaudelthrs=${iau_delthrs}
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
fntsfa=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/${RUN}.t${houra}z.rtgssthr.grb
#fntsfa=/scratch2/BMC/gsienkf/Philip.Pegion/obs/ostia/grb_files/${RUN}.${yeara}${mona}${daya}/${houra}/${RUN}.t${houra}z.ostia_sst.grb
fnacna=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/${RUN}.t${houra}z.seaice.5min.grb
#fnacna=/scratch2/BMC/gsienkf/Philip.Pegion/obs/ostia/grb_files/${RUN}.${yeara}${mona}${daya}/${houra}/${RUN}.t${houra}z.ostia_ice_fraction.grb
fnsnoa=${obs_datapath}/${RUN}.${yeara}${mona}${daya}/${houra}/${RUN}.t${houra}z.snogrb_t1534.3072.1536
fnsnog=${obs_datapath}/${RUN}.${yearprev}${monprev}${dayprev}/${hourprev}/${RUN}.t${hourprev}z.snogrb_t1534.3072.1536
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

if [ $nanals2 -gt 0 ] && [ $nmem -le $nanals2 ]; then
   longer_fcst="YES"
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

# use these for both model gcyc and global_cycle util.
# &NAMCYC
#  idim=$CRES, jdim=$CRES, lsoil=$LSOIL,
#  iy=$iy, im=$im, id=$id, ih=$ih, fh=$FHOUR,
#  deltsfc=$DELTSFC,ialb=$IALB,use_ufo=$use_ufo,donst=$DONST,
#  do_sfccycle=$DO_SFCCYCLE,do_lndinc=$DO_LNDINC,isot=$ISOT,ivegsrc=$IVEGSRC,
#  zsea1_mm=$zsea1,zsea2_mm=$zsea2,MAX_TASKS=$MAX_TASKS_CY
# /
#export IALB=1 # modis albedo (default)
#export ISOT=1 # statsgo soil type (default)
#export IVEGSRC=1 # igbp veg type (default)
export FNGLAC="${FIXDIR}/fix_am/global_glacier.2x2.grb"
export FNMXIC="${FIXDIR}/fix_am/global_maxice.2x2.grb"
export FNTSFC="${FIXDIR}/fix_am/RTGSST.1982.2012.monthly.clim.grb"
export FNSNOC="${FIXDIR}/fix_am/global_snoclim.1.875.grb"
export FNZORC="igbp"
export FNAISC="${FIXDIR}/fix_am/CFSR.SEAICE.1982.2012.monthly.clim.grb"
 if [ $FRAC_GRID == ".true." ]; then
export FNALBC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.snowfree_albedo.tileX.nc"
export FNALBC2="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.facsf.tileX.nc"
export FNTG3C="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.substrate_temperature.tileX.nc"
export FNVEGC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNVETC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.vegetation_type.tileX.nc"
export FNSOTC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.soil_type.tileX.nc"
export FNVMNC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNVMXC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNSLPC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.slope_type.tileX.nc"
export FNABSC="${FIXDIR}/fix_fv3_fracoro/C${RES}.${OCNRES}_frac/fix_sfc/C${RES}.maximum_snow_albedo.tileX.nc"
else
export FNALBC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.snowfree_albedo.tileX.nc"
export FNALBC2="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.facsf.tileX.nc"
export FNTG3C="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.substrate_temperature.tileX.nc"
export FNVEGC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNVETC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.vegetation_type.tileX.nc"
export FNSOTC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.soil_type.tileX.nc"
export FNVMNC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNVMXC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.vegetation_greenness.tileX.nc"
export FNSLPC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.slope_type.tileX.nc"
export FNABSC="${FIXDIR}/fix_fv3_gmted2010/C${RES}/fix_sfc/C${RES}.maximum_snow_albedo.tileX.nc"
fi
export FNSMCC="${FIXDIR}/fix_am/global_soilmgldas.statsgo.t766.1536.768.grb"
export FNMSKH="${FIXDIR}/fix_am/global_slmask.t1534.3072.1536.grb"
export FNTSFA="${fntsfa}"
export FNACNA="${fnacna}"
export FNSNOA="${fnsnoa}"
export LDEBUG=.false.
export FSMCL2=99999 
export FSMCL3=99999 
export FSMCL4=99999 
export LANDICE=.false.
export FTSFS=99999
export FAISL=99999
export FAISS=99999
export FSNOS=99999
export FSICL=99999    
export FSICS=99999
export FTSFL=99999
export FVETL=99999
export FSOTL=99999
export FvmnL=99999
export FvmxL=99999
export FSLPL=99999
export FABSL=99999
export CYCLVARS="FSNOL=${FSNOL},FSNOS=${FSNOS},LANDICE=${LANDICE}"
export NAMSFC="$PWD/namsfc.nml" # must be absolute path
if [ -z $skip_global_cycle ]; then
cat << EOF > $NAMSFC
&NAMSFC
  FNGLAC="$FNGLAC",
  FNMXIC="$FNMXIC",
  FNTSFC="$FNTSFC",
  FNSNOC="$FNSNOC",
  FNZORC="$FNZORC",
  FNALBC="$FNALBC",
  FNALBC2="$FNALBC2",
  FNAISC="$FNAISC",
  FNTG3C="$FNTG3C",
  FNVEGC="$FNVEGC",
  FNVETC="$FNVETC",
  FNSOTC="$FNSOTC",
  FNSMCC="$FNSMCC",
  FNVMNC="$FNVMNC",
  FNVMXC="$FNVMXC",
  FNSLPC="$FNSLPC",
  FNABSC="$FNABSC",
  FNMSKH="$FNMSKH",
  FNTSFA="$FNTSFA",
  FNACNA="$FNACNA",
  FNSNOA="$FNSNOA",
  LDEBUG=$LDEBUG,
  FSLPL=$FSLPL,
  FSOTL=$FSOTL,
  FVETL=$FVETL,
  FSMCL(2)=$FSMCL2,
  FSMCL(3)=$FSMCL3,
  FSMCL(4)=$FSMCL4,
  $CYCLVARS
 /
EOF
else
cat << EOF > $NAMSFC
&namsfc
  FNGLAC="$FNGLAC",
  FNMXIC="$FNMXIC",
  FNTSFC="$FNTSFC",
  FNSNOC="$FNSNOC",
  FNZORC="$FNZORC",
  FNALBC="$FNALBC",
  FNALBC2="$FNALBC2",
  FNAISC="$FNAISC",
  FNTG3C="$FNTG3C",
  FNVEGC="$FNVEGC",
  FNVETC="$FNVETC",
  FNSOTC="$FNSOTC",
  FNSMCC="$FNSMCC",
  FNVMNC="$FNVMNC",
  FNVMXC="$FNVMXC",
  FNSLPC="$FNSLPC",
  FNABSC="$FNABSC",
  FNMSKH="$FNMSKH",
  FNTSFA="$FNTSFA",
  FNACNA="$FNACNA",
  FNSNOA="$FNSNOA",
  LDEBUG   = $LDEBUG,
  FSMCL(2) = $FSMCL2,
  FSMCL(3) = $FSMCL3,
  FSMCL(4) = $FSMCL4,
  LANDICE = $LANDICE,
  FTSFS = 99999
  FAISL = 99999
  FAISS = 99999
  FSNOL = $FSNOL
  FSNOS = $FSNOS
  FSICL = 99999    
  FSICS = 99999
  FTSFL = 99999
  FVETL = 99999
  FSOTL = 99999
  FvmnL = 99999
  FvmxL = 99999
  FSLPL = 99999
  FABSL = 99999
/
EOF
fi

if [ $cold_start = "false" ] && [ -z $skip_global_cycle ]; then
   # run global_cycle to update surface in restart file.
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
   if [ $NST_GSI -gt 1 ]; then
       export NST_FILE=${datapath2}/${PREINP}dtfanl.nc
   else
       export NST_FILE="NULL"
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

export timestep_hrs=`python -c "from __future__ import print_function; print($dt_atmos / 3600.)"`
if [ $cold_start == "true" ] && [ $analdate -gt 2021032400 ]; then
   restart_interval="$timestep_hrs $ANALINC"
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
fhrot:                   ${FHROT}
quilting:                .true.
write_groups:            ${write_groups}
write_tasks_per_group:   ${write_tasks}
num_files:               2
filename_base:           'dyn' 'phy'
output_grid:             'gaussian_grid'
output_file:             'netcdf' 'netcdf'
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
#sed -i -e "s/SUITE/${SUITE}/g" input.nml
sed -i -e "s/LAYOUT/${layout}/g" input.nml
sed -i -e "s/NPX/${npx}/g" input.nml
sed -i -e "s/NPY/${npx}/g" input.nml
sed -i -e "s/LEVP/${LEVP}/g" input.nml
sed -i -e "s/LEVS/${LEVS}/g" input.nml
sed -i -e "s/IAU_DELTHRS/${iaudelthrs}/g" input.nml
sed -i -e "s/IAU_INC_FILES/${iau_inc_files}/g" input.nml
sed -i -e "s/WARM_START/${warm_start}/g" input.nml
sed -i -e "s/CDMBGWD/${cdmbgwd}/g" input.nml
sed -i -e "s/EXTERNAL_IC/${externalic}/g" input.nml
sed -i -e "s/NA_INIT/${na_init}/g" input.nml
sed -i -e "s/MOUNTAIN/${mountain}/g" input.nml
sed -i -e "s/FRAC_GRID/${FRAC_GRID}/g" input.nml
sed -i -e "s/ISEED_CA/${ISEED_CA}/g" input.nml
sed -i -e "s/RESLATLONDYNAMICS/${reslatlondynamics}/g" input.nml
sed -i -e "s/READ_INCREMENT/${readincrement}/g" input.nml
# gcycle related params
sed -i -e "s/FHCYC/${FHCYC}/g" input.nml
#sed -i -e "s/CRES/C${RES}/g" input.nml
#sed -i -e "s/ORES/${OCNRES}/g" input.nml
#sed -i -e "s!SSTFILE!${fntsfa}!g" input.nml
#sed -i -e "s!FIXDIR!${FIXDIR}!g" input.nml
#sed -i -e "s!ICEFILE!${fnacna}!g" input.nml
#sed -i -e "s!SNOFILE!${fnsnoa}!g" input.nml
#sed -i -e "s/FSNOL_PARM/${FSNOL}/g" input.nml
if [ $NSTFNAME == "2,0,0,0" ] && [ $cold_start == "true" ]; then
   NSTFNAME="2,1,0,0"
fi
sed -i -e "s/NSTFNAME/${NSTFNAME}/g" input.nml

sed -i -e "s/DO_sppt/${DO_SPPT}/g" input.nml
sed -i -e "s/DO_shum/${DO_SHUM}/g" input.nml
sed -i -e "s/DO_skeb/${DO_SKEB}/g" input.nml

sed -i -e "s/LONB/${LONB}/g" input.nml
sed -i -e "s/LATB/${LATB}/g" input.nml
sed -i -e "s/JCAP/${JCAP}/g" input.nml
sed -i -e "s/SPPT/${SPPT}/g" input.nml
sed -i -e "s/SHUM/${SHUM}/g" input.nml
sed -i -e "s/SKEB/${SKEB}/g" input.nml
sed -i -e "s/STOCHINI/${stochini}/g" input.nml
sed -i -e "s/ISEED_sppt/${ISEED_SPPT}/g" input.nml
sed -i -e "s/ISEED_shum/${ISEED_SHUM}/g" input.nml
sed -i -e "s/ISEED_skeb/${ISEED_SKEB}/g" input.nml

cp input.nml input.nml.tmp
cat input.nml.tmp $NAMSFC > input.nml
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
# rename netcdf history files.
ls -l dyn*.nc
ls -l phy*.nc
fh=$FHMIN
while [ $fh -le $FHMAX ]; do
  charfhr="fhr"`printf %02i $fh`
  charfhr2="f"`printf %03i $fh`
  if [ $longer_fcst = "YES" ] && [ $fh -eq $FHMAX ]; then
     /bin/cp -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
  else
     /bin/mv -f dyn${charfhr2}.nc ${DATOUT}/sfg_${analdatep1}_${charfhr}_${charnanal}
  fi
  if [ $? -ne 0 ]; then
     echo "netcdffile missing..."
     exit 1
  fi
  if [ $longer_fcst = "YES" ] && [ $fh -eq $FHMAX ]; then
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
    fh=$FHMAX
    analdatep2=`$incdate $analdatep1 $ANALINC`
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
