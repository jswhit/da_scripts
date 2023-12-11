obtyp_default="all"
YYYYMMDDHH=${analdate:-$1}
OUTPATH=${obs_datapath:-$2}
obtyp=${obtyp_default:-$3} # specify single ob type, default is all obs.

which aws
if [ $? -ne 0 ]; then
   echo "SLURM_CLUSTER_NAME=$SLURM_CLUSTER_NAME"
   if  [ $SLURM_CLUSTER_NAME == 'es' ]; then #
      source /lustre/f2/dev/role.epic/contrib/Lmod_init.sh
      module use /lustre/f2/dev/wpo/role.epic/contrib/spack-stack/c4/modulefiles
      module use /lustre/f2/dev/wpo/role.epic/contrib/spack-stack/c4/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
      module load stack-intel/2022.0.2
      module load awscli
   elif [ $SLURM_CLUSTER_NAME == 'hercules' ]; then
      module purge
      module use /work/noaa/epic/role-epic/spack-stack/hercules/modulefiles
      module use /work/noaa/epic/role-epic/spack-stack/hercules//spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
      module load stack-intel/2021.9.0
      module load awscli
   else
      echo "cluster must be 'hercules' or 'es' (gaea)"
      exit 1
   fi
fi
which aws
if [ $? -ne 0 ]; then
   echo "awscli not found"
   exit 1
fi

YYYYMM=`echo $YYYYMMDDHH | cut -c1-6`
YYYYMMDD=`echo $YYYYMMDDHH | cut -c1-8`
HH=`echo $YYYYMMDDHH | cut -c9-10`
DD=`echo $YYYYMMDDHH | cut -c7-8`
MM=`echo $YYYYMMDDHH | cut -c5-6`
YYYY=`echo $YYYYMMDDHH | cut -c1-4`
CDUMP='gdas'
S3PATH=/noaa-reanalyses-pds/observations/reanalysis
# directory structure required by global-workflow
TARGET_DIR=${OUTPATH}/${CDUMP}.${YYYYMMDD}/${HH}/atmos
mkdir -p $TARGET_DIR
obtypes=("airs" "amsua" "amsub" "amv" "atms" "cris" "cris" "geo" "geo" "gps" "hirs" "hirs" "hirs" "iasi" "mhs" "msu" "saphir" "seviri" "ssmi" "ssmis" "ssu")
if [ $YYYYMMDDHH -lt "2009050106" ]; then
# before 2009050106 for amsua use nasa/r21c_repro/gmao_r21c_repro
   dirs=("nasa" "nasa/r21c_repro" "1bamub" "merged" "atms" "cris" "crisf4" "goesnd" "goesfv" "gpsro" "1bhrs2" "1bhrs3" "1bhrs4" "mtiasi" "1bmhs" "1bmsu" "saphir" "sevcsr" "eumetsat" "eumetsat" "1bssu")
   obnames=("aqua" "1bamu" "1bamub" "satwnd" "atms" "cris" "crisf4" "goesnd" "goesfv" "gpsro" "1bhrs2" "1bhrs3" "1bhrs4" "mtiasi" "1bmhs" "1bmsu" "saphir" "sevcsr" "ssmit" "ssmisu" "1bssu")
   dumpnames=("airs_disc_final" "gmao_r21c_repro" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas")
else
   dirs=("nasa" "1bamua" "1bamub" "merged" "atms" "cris" "crisf4" "goesnd" "goesfv" "gpsro" "1bhrs2" "1bhrs3" "1bhrs4" "mtiasi" "1bmhs" "1bmsu" "saphir" "sevcsr" "eumetsat" "eumetsat" "1bssu")
   obnames=("aqua" "1bamua" "1bamub" "satwnd" "atms" "cris" "crisf4" "goesnd" "goesfv" "gpsro" "1bhrs2" "1bhrs3" "1bhrs4" "mtiasi" "1bmhs" "1bmsu" "saphir" "sevcsr" "ssmit" "ssmisu" "1bssu")
   dumpnames=("airs_disc_final" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas" "gdas")
fi
for n in ${!obtypes[@]}; do
  if [ ${obtypes[$n]} == $obtyp ] || [ $obtyp == "all" ]; then
     if [ ${obtypes[$n]} == "airs" ] && [ ${dirs[$n]} == "nasa" ]; then
        # NASA airs obs
        s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${obnames[$n]}/${YYYY}/${MM}/bufr/${dumpnames[$n]}.${YYYYMMDD}.t${HH}z.bufr"
        localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.airsev.tm00.bufr_d"
     elif [ ${obtypes[$n]} == "amsua" ] && [ ${dirs[$n]} == "nasa/r21c_repro" ]; then
        s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${YYYY}/${MM}/bufr/${dumpnames[$n]}.${YYYYMMDD}.t${HH}z.${obnames[$n]}.tm00.bufr"
        localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.1bamua.tm00.bufr_d"
     else
        s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${YYYY}/${MM}/bufr/${dumpnames[$n]}.${YYYYMMDD}.t${HH}z.${obnames[$n]}.tm00.bufr_d"
        localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.${obnames[$n]}.tm00.bufr_d"
     fi
     #aws s3 ls --no-sign-request $s3file
     aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
     #ls -l $localfile
  fi
done
# prepbufr
obtypes="prepbufr prepbufr.acft_profiles"
for obtype in $obtypes; do
   if [ ${obtypes[$n]} == $obtyp ] || [ $obtyp == "all" ]; then
      if [ $obtype == "prepbufr" ]; then
         s3file=s3:/"${S3PATH}/conv/${obtype}/${YYYY}/${MM}/prepbufr/gdas.${YYYYMMDD}.t${HH}z.${obtype}.nr"
      else
         s3file=s3:/"${S3PATH}/conv/${obtype}/${YYYY}/${MM}/bufr/gdas.${YYYYMMDD}.t${HH}z.${obtype}.nr"
      fi
      localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.${obtype}"
      #aws s3 ls --no-sign-request $s3file
      aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
      #ls -l $localfile
   fi
done
# ozone
# CFSR
if [ $obtyp == "osbuv8" ] || [ $obtyp == "all" ]; then
   s3file=s3:/"${S3PATH}/ozone/cfsr/${YYYY}/${MM}/bufr/gdas.${YYYYMMDD}.t${HH}z.osbuv8.tm00.bufr_d"
   localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.osbuv8.tm00.bufr_d"
   #aws s3 ls --no-sign-request $s3file
   aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
   #ls -l $localfile
fi
# NCEP bufr
obtypes=("ozone" "ozone" "ozone")
dirs=("ncep" "ncep" "ncep")
obnames=("omps-lp" "ompsn8" "ompst8")
dumpnames=("gdas" "gdas" "gdas")
for n in ${!obtypes[@]}; do
  if [ ${obtypes[$n]} == $obtyp ] || [ $obtyp == "all" ]; then
     if [ ${obnames[$n]} == 'omps-lp' ]; then
        s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${obnames[$n]}/${YYYY}/${MM}/bufr/${dumpnames[$n]}.${YYYYMMDD}.t${HH}z.ompslp.tm00.bufr_d"
        localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.ompslp.tm00.bufr_d"
     else
        s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${obnames[$n]}/${YYYY}/${MM}/bufr/${dumpnames[$n]}.${YYYYMMDD}.t${HH}z.${obnames[$n]}.tm00.bufr_d"
        localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.${obnames[$n]}.tm00.bufr_d"
     fi
     #aws s3 ls --no-sign-request $s3file
     aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
     #ls -l $localfile
  fi
done
# NASA bufr
if [ $obtyp == "sbuv_v87" ] || [ $obtyp == "all" ]; then
   s3file=s3:/"${S3PATH}/ozone/nasa/sbuv_v87/${YYYY}/${MM}/bufr/sbuv_v87.${YYYYMMDD}.${HH}z.bufr"
   localfile="${TARGET_DIR}/${CDUMP}.t${HH}z.sbuv_v87.tm00.bufr_d"
   #aws s3 ls --no-sign-request $s3file
   aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
   #ls -l $localfile
fi
# NASA netcdf
obtypes=("ozone" "ozone" "ozone" "ozone" "ozone")
dirs=("nasa" "nasa" "nasa" "nasa" "nasa")
obnames=("mls" "omi-eff" "omps-lp" "omps-nm-eff" "omps-nm")
dumpnames=("MLS-v5.0-oz" "OMIeff-adj" "OMPS-LPoz-Vis" "OMPSNM" "OMPSNP")
for n in ${!obtypes[@]}; do
  if [ ${obtypes[$n]} == $obtyp ] || [ $obtyp == "all" ]; then
     s3file=s3:/"${S3PATH}/${obtypes[$n]}/${dirs[$n]}/${obnames[$n]}/${YYYY}/${MM}/netcdf/${dumpnames[$n]}.${YYYYMMDD}_${HH}z.nc"
     localfile="${TARGET_DIR}/${dumpnames[$n]}.${YYYYMMDD}_${HH}z.nc"
     #aws s3 ls --no-sign-request $s3file
     aws s3 cp --no-sign-request --only-show-errors $s3file $localfile &
     #ls -l $localfile
  fi
done
wait
ls -l ${TARGET_DIR}
