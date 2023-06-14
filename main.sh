#!/bin/sh

# main driver script
# gsi gain or gsi covariance GSI EnKF

# allow this script to submit other scripts with LSF
unset LSB_SUB_RES_REQ 

echo "nodes = $NODES"

idate_job=1

while [ $idate_job -le ${ndates_job} ]; do

source $datapath/fg_only.sh # define fg_only variable.

export startupenv="${datapath}/analdate.sh"
source $startupenv
# substringing to get yr, mon, day, hr info
export yr=`echo $analdate | cut -c1-4`
export mon=`echo $analdate | cut -c5-6`
export day=`echo $analdate | cut -c7-8`
export hr=`echo $analdate | cut -c9-10`
# previous analysis time.
export analdatem1=`${incdate} $analdate -$ANALINC`
# next analysis time.
export analdatep1=`${incdate} $analdate $ANALINC`
export hrp1=`echo $analdatep1 | cut -c9-10`
export hrm1=`echo $analdatem1 | cut -c9-10`
# next analysis time.
export analdatep1=`${incdate} $analdate 1`
export sixhourlydumps=${sixhourlydumps:-"YES"}
if [ $sixhourlydumps == "YES" ]; then
   export obdate=`python findobdate.py $analdate`
else
   export obdate=$analdate
fi

# convinfo, ozinfo, satinfo from env vars CONVINFO, OZINFO, SATINFO

if [ ! -z $HYBENSINFO ]; then
   /bin/cp -f ${HYBENSINFO} ${datapath}/${analdate}/hybens_info
fi
if [ ! -z $HYBENSMOOTHINFO ];  then
   /bin/cp -f ${HYBENSMOOTHINFO} $datapath2/${analdate}/hybens_smoothinfo
fi

#------------------------------------------------------------------------
mkdir -p $datapath

echo "BaseDir: ${basedir}"
echo "EnKFBin: ${enkfbin}"
echo "DataPath: ${datapath}"

############################################################################
# Main Program

env
echo "starting the cycle (${idate_job} out of ${ndates_job})"

export datapath2="${datapath}/${analdate}/"
/bin/cp -f ${ANAVINFO_ENKF} ${datapath2}/anavinfo

# setup node parameters used in blendinc.sh and compute_ensmean_fcst.sh
export mpitaskspernode=`python -c "from __future__ import print_function; import math; print(int(math.ceil(float(${nanals})/float(${NODES}))))"`
if [ $mpitaskspernode -lt 1 ]; then
  export mpitaskspernode 1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals

export datapathp1="${datapath}/${analdatep1}/"
export datapathm1="${datapath}/${analdatem1}/"
mkdir -p $datapathp1
export CDATE=$analdate

date
echo "analdate minus 1: $analdatem1"
echo "analdate: $analdate"
echo "analdate plus 1: $analdatep1"

# make log dir for analdate
export current_logdir="${datapath2}/logs"
echo "Current LogDir: ${current_logdir}"
mkdir -p ${current_logdir}

# if nanals2>0, extend nanals2 members out to FHMAX_LONGER=6
# but only at 03,09,15,21 UTC (for comparison with 6-h cycled system)
if [ $hr = "03" ] || [ $hr = "09" ] || [ $hr = "15" ] || [ $hr = "21" ]; then
  if [ $cold_start == "true" ]; then
    export nanals2=-1
    echo "no longer forecast extension"
  else
     export nanals2=80
     echo "will run $nanals2 members out to hour $FHMAX_LONGER"
  fi
else
  export nanals2=-1
  echo "no longer forecast extension"
fi
if [ $FHCYC -gt 0 ]; then
   if [ $hr = "00" ] || [ $hr = "06" ] || [ $hr = "12" ] || [ $hr = "18" ]; then
    echo "gcycle will be run with FHCYC=$FHCYC"
   else
    export FHCYC=0
    export skip_global_cycle=1
    echo "don't run gcycle"
   fi
else
   if [ $hr = "00" ] || [ $hr = "06" ] || [ $hr = "12" ] || [ $hr = "18" ]; then
    unset skip_global_cycle
    echo "global_cycle will be run"
   else
    export skip_global_cycle=1
    echo "don't run global_cycle (or gcycle)"
   fi
fi
#if [ $hr = "04" ] || [ $hr = "10" ] || [ $hr = "16" ] || [ $hr = "22" ]; then
#   export time_window_max=1.0
#   export min_offset=60
#   export nhr_assimilation=2
#   export CONVINFO=${enkfscripts}/global_convinfo.txt2
#else
   export time_window_max=0.5
   export min_offset=30
   export nhr_assimilation=1
   export CONVINFO=${enkfscripts}/global_convinfo.txt
#fi

export PREINP="${RUN}.t${hr}z."
export PREINP1="${RUN}.t${hrp1}z."
export PREINPm1="${RUN}.t${hrm1}z."

# loop over outer iterations
export nliteration=1
if [ $cold_start == 'true' ]; then
   export nliterations=1
fi
while [ $nliteration -le $nliterations ]; do

echo "nonlinear iteration $nliteration out of $nliterations"

if [ $fg_only ==  'false' ]; then

niter=1
alldone="no"
while [ $alldone == 'no' ] && [ $niter -le $nitermax ]; do
   echo "$analdate starting ens mean computation `date`"
   sh ${enkfscripts}/compute_ensmean_fcst.sh >  ${current_logdir}/compute_ensmean_fcst.out 2>&1
   errstatus=$?
   if [ $errstatus -ne 0 ]; then
       echo "failed computing ensemble mean, try again..."
       alldone="no"
       if [ $niter -eq $nitermax ]; then
           echo "giving up"
           exit 1
       fi
   else
       echo "$analdate done computing ensemble mean `date`"
       alldone="yes"
   fi
   niter=$((niter+1))
done

# change orography in high-res control forecast nemsio file so it matches enkf ensemble,
# adjust surface pressure accordingly.
# this file only used to calculate analysis increment for replay
errexit=0
if [ $replay_controlfcst == 'true' ]; then
   charnanal='control'
   echo "$analdate change resolution of control forecast to ens resolution `date`"
   #fh=$FHMIN
   fh=0
   while [ $fh -le $FHMAX ]; do
     fhr=`printf %02i $fh`
     # run concurrently, wait
     sh ${enkfscripts}/chgres.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal}.chgres > ${current_logdir}/chgres_${fhr}.out 2>&1 &
     errstatus=$?
     if [ $errstatus -ne 0 ]; then
       errexit=$errstatus
     fi
     fh=$((fh+FHOUT))
   done
   wait
   if [ $errexit -ne 0 ]; then
      echo "adjustps/chgres step failed, exiting...."
      exit 1
   fi
   echo "$analdate done changing resolution of control forecast to ens resolution `date`"
fi

# optionally (partially) recenter ensemble around control forecast.
if [ $replay_controlfcst == 'true' ] && [ $recenter_control_wgt -gt 0 ] && [ $recenter_fcst == "true" ]; then
   echo "$analdate (partially) recenter background ensemble around control `date`"
   export fileprefix="sfg"
   export charnanal="control.chgres"
   sh ${enkfscripts}/recenter_ens.sh > ${current_logdir}/recenter_ens_fcst.out 2>&1
   recenter_done=`cat ${current_logdir}/recenter.log`
   if [ $recenter_done == 'yes' ]; then
     echo "$analdate recentering completed successfully `date`"
   else
     echo "$analdate recentering did not complete successfully, exiting `date`"
     exit 1
   fi
fi

# if ${datapathm1}/cold_start_bias exists, GSI run in 'observer' mode
# to generate diag_rad files to initialize angle-dependent 
# bias correction.
if [ -f ${datapathm1}/cold_start_bias ]; then
   export cold_start_bias="true"
else
   export cold_start_bias="false"
fi

# use ensmean mean background for 3dvar analysis/observer calculatino
export charnanal='control' 
export charnanal2='ensmean'
export lobsdiag_forenkf='.true.'
export skipcat="false"
# run Var analysis
# symlink ens mean backgrounds to "control"
#fh=$FHMIN
fh=0
while [ $fh -le $FHMAX ]; do
  fhr=`printf %02i $fh`
  /bin/ln -fs ${datapath2}/sfg_${analdate}_fhr${fhr}_ensmean ${datapath2}/sfg_${analdate}_fhr${fhr}_control
  /bin/ln -fs ${datapath2}/bfg_${analdate}_fhr${fhr}_ensmean ${datapath2}/bfg_${analdate}_fhr${fhr}_control
  fh=$((fh+FHOUT))
done
if [ $hybgain == "true" ]; then
  type="3DVar"
else
  type="hybrid 4DEnVar"
fi
echo "$analdate run $type `date`"
sh ${enkfscripts}/run_gsianal.sh > ${current_logdir}/run_gsianal_${nliteration}.out 2>&1
# once gsi has completed, check log files.
gsi_done=`cat ${current_logdir}/run_gsi_anal.log`
if [ $gsi_done == 'yes' ]; then
 echo "$analdate $type analysis completed successfully `date`"
else
 echo "$analdate $type analysis did not complete successfully, exiting `date`"
 exit 1
fi

# loop over members run observer sequentially (for testing)
#export skipcat="false"
#nanal=0
#ncount=0
#while [ $nanal -le $nanals ]; do
#   if [ $nanal -eq 0 ]; then
#     export charnanal="ensmean"
#     export charnanal2="ensmean"
#   else
#     export charnanal="mem"`printf %03i $nanal`
#     export charnanal2=$charnanal 
#   fi
#   export lobsdiag_forenkf='.false.'
#   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
#   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer_${charnanal}.out 2>&1 &
#   ncount=$((ncount+1))
#   if [ $ncount -eq $NODES ]; then
#      echo "waiting at nanal = $nanal ..."
#      wait
#      ncount=0
#   fi
#   nanal=$((nanal+1))
#done
#wait
#nanal=0
#while [ $nanal -le $nanals ]; do
#   if [ $nanal -eq 0 ]; then
#     export charnanal="ensmean"
#     export charnanal2="ensmean"
#   else
#     export charnanal="mem"`printf %03i $nanal`
#     export charnanal2=$charnanal 
#   fi
#   # once observer has completed, check log files.
#   gsi_done=`cat ${current_logdir}/run_gsi_observer_${charnanal}.log`
#   if [ $gsi_done == 'yes' ]; then
#     echo "$analdate gsi observer $charnanal completed successfully `date`"
#   else
#     echo "$analdate gsi observer $charnanal did not complete successfully, exiting `date`"
#     exit 1
#   fi
#   nanal=$((nanal+1))
#done

# run enkf analysis.
echo "$analdate run enkf `date`"
sh ${enkfscripts}/runenkf.sh > ${current_logdir}/run_enkf_${nliteration}.out 2>&1
# once enkf has completed, check log files.
enkf_done=`cat ${current_logdir}/run_enkf.log`
if [ $enkf_done == 'yes' ]; then
  echo "$analdate enkf analysis completed successfully `date`"
else
  echo "$analdate enkf analysis did not complete successfully, exiting `date`"
  exit 1
fi

# compute ensemble mean analyses.
if [ $write_ensmean == ".false." ]; then
   echo "$analdate starting ens mean analysis computation `date`"
   sh ${enkfscripts}/compute_ensmean_enkf.sh > ${current_logdir}/compute_ensmean_anal.out 2>&1
   echo "$analdate done computing ensemble mean analyses `date`"
fi

if [ $nliteration -eq 1 ] && [ $nliterations -gt 1 ]; then
  # save diag files for 1st iteration
  mkdir ${datapath2}/diagfiles_1
  mkdir ${datapath2}/sfgfiles_1
  pushd ${datapath2}
  /bin/mv -f ${datapath2}/diag*nc4 diagfiles_1
  /bin/cp -f ${datapath2}/sfg*ensmean sfgfiles_1
  popd
fi

# blend enkf mean and 3dvar increments, recenter ensemble
#if [ $recenter_anal == "true" ]; then
#   if [ $hybgain == "true" ]; then 
#       if [ $alpha -gt 0 ]; then
#          # hybrid gain
#          echo "$analdate blend enkf and 3dvar increments `date`"
#          sh ${enkfscripts}/blendinc.sh > ${current_logdir}/blendinc.out 2>&1
#          blendinc_done=`cat ${current_logdir}/blendinc.log`
#          if [ $blendinc_done == 'yes' ]; then
#            echo "$analdate increment blending/recentering completed successfully `date`"
#          else
#            echo "$analdate increment blending/recentering did not complete successfully, exiting `date`"
#            exit 1
#          fi
#       fi
#   else
#       # hybrid covariance, recenter
#       export fileprefix="sanl"
#       export charnanal="control"
#       echo "$analdate recenter enkf analysis ensemble around control analysis `date`"
#       sh ${enkfscripts}/recenter_ens.sh > ${current_logdir}/recenter_ens_anal.out 2>&1
#       recenter_done=`cat ${current_logdir}/recenter.log`
#       if [ $recenter_done == 'yes' ]; then
#         echo "$analdate recentering enkf analysis completed successfully `date`"
#       else
#         echo "$analdate recentering enkf analysis did not complete successfully, exiting `date`"
#         exit 1
#       fi
#
#       # use increment blending util with alpha=1, beta=0 instead of recentering
#       #echo "$analdate blend enkf and 3dvar increments `date`"
#       ## for hybrd cov could use alpha=1, beta=0 here 
#       #alpha_save=$alpha
#       #beta_save=$beta
#       #export alpha=1000
#       #export beta=0
#       #sh ${enkfscripts}/blendinc.sh > ${current_logdir}/blendinc.out 2>&1
#       #blendinc_done=`cat ${current_logdir}/blendinc.log`
#       #if [ $blendinc_done == 'yes' ]; then
#       #  echo "$analdate increment blending/recentering completed successfully `date`"
#       #else
#       #  echo "$analdate increment blending/recentering did not complete successfully, exiting `date`"
#       #  exit 1
#       #fi
#       #export alpha=$alpha_save
#       #export beta=$beta_save
#   fi
#fi

# compute anal ens mean, blend enkf mean and 3dvar increments, recenter ensemble, taper perts near model top
export fileprefix="sanl"
echo "$analdate recenter or blend increments, and taper enkf analysis ens perts near top of model `date`"
sh ${enkfscripts}/taper_ens.sh > ${current_logdir}/taper_ensperts_anal.out 2>&1
taper_done=`cat ${current_logdir}/taper.log`
if [ $taper_done == 'yes' ]; then
  echo "$analdate recentering, increment blending and tapering enkf analysis ens perts completed successfully `date`"
else
  echo "$analdate recentering, increment blending and tapering enkf analysis ens perts did not complete successfully, exiting `date`"
  exit 1
fi

# for passive (replay) cycling of control forecast, optionally run GSI observer
# on control forecast background (diag files saved with 'control' suffix)
if [ $replay_controlfcst == 'true' ] && [ $replay_run_observer == "true" ]; then
   export charnanal='control' 
   export charnanal2='control' 
   export lobsdiag_forenkf='.false.'
   export skipcat="false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observerc.out 2>&1
   # once observer has completed, check log files.
   gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $gsi_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
fi

# run gsi observer on forecast extension
#if [ $analdate -ge 2021090100 ] && [ -s $datapath2/sfg2_${analdate}_fhr06_ensmean ]; then
if [ -s $datapath2/sfg2_${analdate}_fhr06_ensmean ]; then
   export charnanal='ensmean' 
   export charnanal2='ensmean2' 
   export lobsdiag_forenkf='.false.'
   export skipcat="false"
   FHMIN_SAVE=$FHMIN
   FHMAX_SAVE=$FHMAX
   ANALINC_SAVE=$ANALINC
   CONVINFO_SAVE=$CONVINFAO
   export FHMIN=3
   export FHMAX=9
   export ANALINC=6
   export CONVINFO=${fixgsi}/gfsv16_historical/global_convinfo.txt.2021052012
   export ATMPREFIX='sfg2'
   export SFCPREFIX='bfg2'
   analdatem1_save=$analdatem1
   datapathm1_save=$datapathm1
   # use bias correction from analysis 4 hours ago (fcst was initialized 3 hours ago)
   export analdatem1=`${incdate} $analdate -4`
   export hrm1=`echo $analdatem1 | cut -c9-10`
   export datapathm1="${datapath}/${analdatem1}/"
   export PREINPm1="gdas.t${hrm1}z."
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsiobserver2.out 2>&1
   # once observer has completed, check log files.
   gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $gsi_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
   if [ $replay_controlfcst == 'true' ] && [ $replay_run_observer == "true" ]; then
      export charnanal='control'
      export charnanal2='control2'
      echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
      sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsiobserver2c.out 2>&1
      # once observer has completed, check log files.
      gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
      if [ $gsi_done == 'yes' ]; then
        echo "$analdate gsi observer completed successfully `date`"
      else
        echo "$analdate gsi observer did not complete successfully, exiting `date`"
        exit 1
      fi
   fi
   export FHMIN=$FHMIN_SAVE
   export FHMAX=$FHMAX_SAVE
   export ANALINC=$ANALINC_SAVE
   export CONVINFO=$CONVINFO_SAVE
   export analdatem1=$analdatem1_save
   export datapathm1=$datapathm1_save
   unset ATMPREFIX
   unset SFCPREFIX
fi

fi # skip to here if fg_only = true


if [ $replay_controlfcst == 'true' ]; then
    echo "$analdate run high-res control first guess `date`"
    sh ${enkfscripts}/run_fg_control.sh  > ${current_logdir}/run_fg_control.out  2>&1
    control_done=`cat ${current_logdir}/run_fg_control.log`
    if [ $control_done == 'yes' ]; then
      echo "$analdate high-res control first-guess completed successfully `date`"
    else
      echo "$analdate high-res control did not complete successfully, exiting `date`"
      exit 1
    fi
fi

#if [ $fg_only == "true" ]; then
   echo "$analdate run enkf ens first guess `date`"
   sh ${enkfscripts}/run_fg_ens.sh > ${current_logdir}/run_fg_ens_${nliteration}.out  2>&1
   ens_done=`cat ${current_logdir}/run_fg_ens.log`
   if [ $ens_done == 'yes' ]; then
     echo "$analdate enkf first-guess completed successfully `date`"
   else
     echo "$analdate enkf first-guess did not complete successfully, exiting `date`"
     exit 1
   fi
#fi

export nliteration=$((nliteration+1))

done # next iteration

if [ $cold_start == 'false' ]; then

# cleanup
if [ $fg_only == "true" ]; then
   if [ $do_cleanup == 'true' ]; then
      sh ${enkfscripts}/clean.sh > ${current_logdir}/clean.out 2>&1
   fi # do_cleanup = true
fi

wait # wait for backgrounded processes to finish

if [ $fg_only == "true" ]; then
   # only save full ensemble data to hpss if checkdate.py returns 0
   # a subset will be saved if save_hpss_subset="true" and save_hpss="true"
   date_check=`python ${homedir}/checkdate.py ${analdate}`
   if [ $date_check -eq 0 ]; then
     export save_hpss_full="true"
   else
     export save_hpss_full="false"
   fi
   cd $homedir
   if [ $save_hpss == 'true' ]; then
      cat ${machine}_preamble_hpss hpss.sh > job_hpss.sh
   fi
   sbatch --export=ALL job_hpss.sh
   #sbatch --export=machine=${machine},analdate=${analdate},datapath2=${datapath2},hsidir=${hsidir},save_hpss_full=${save_hpss_full},save_hpss_subset=${save_hpss_subset} job_hpss.sh
fi

fi # skip to here if cold_start = true

echo "$analdate all done"

# next analdate: increment by $ANALINC
#if [ $fg_only == 'true' ]; then
   export analdate=`${incdate} $analdate $ANALINC`
#fi

echo "export analdate=${analdate}" > $startupenv
echo "export analdate_end=${analdate_end}" >> $startupenv
#if [ $fg_only == "true" ]; then
   echo "export fg_only=false" > $datapath/fg_only.sh
#else
#   echo "export fg_only=true" > $datapath/fg_only.sh
#fi
echo "export cold_start=false" >> $datapath/fg_only.sh

cd $homedir

if [ $analdate -le $analdate_end ]; then
  idate_job=$((idate_job+1))
else
  idate_job=$((ndates_job+1))
fi

done # next analysis time


if [ $analdate -le $analdate_end ]  && [ $resubmit == 'true' ]; then
   echo "current time is $analdate"
   if [ $resubmit == 'true' ]; then
      echo "resubmit script"
      echo "machine = $machine"
#      if [ $fg_only == "true" ]; then
         cat ${machine}_preamble config.sh > job.sh
#      else
#         cat ${machine}_preamble2 config.sh > job.sh
#      fi
      sbatch --export=ALL job.sh
   fi
fi

exit 0
