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
export FHOFFSET=`expr $ANALINC \/ 2`
export analdatem1=`${incdate} $analdate -$ANALINC`
# next analysis time.
export analdatep1=`${incdate} $analdate $ANALINC`
# beginning of current assimilation window
export analdatem3=`${incdate} $analdate -$FHOFFSET`
# beginning of next assimilation window
export analdatep1m3=`${incdate} $analdate $FHOFFSET`
export hrp1=`echo $analdatep1 | cut -c9-10`
export hrm1=`echo $analdatem1 | cut -c9-10`

# if SATINFO in obs dir, use it
#if [ -s $obs_datapath/gdas.${yr}${mon}${day}/${hr}/global_satinfo_${analdate}.txt ]; then
#   export  $obs_datapath/gdas.${yr}${mon}${day}/${hr}/global_satinfo_${analdate}.txt
#fi
#export OZINFO=`sh ${enkfscripts}/pickinfo.sh ${analdate} ozinfo`
#export CONVINFO=`sh ${enkfscripts}/pickinfo.sh ${analdate} convinfo`
# if $REALTIME == "YES", use OZINFO,CONVINFO,SATINFO set in config.sh
if [ "$REALTIME" == "NO" ]; then

#cd build_gsinfo
#info=`sh pickinfo.sh $analdate convinfo`
#export CONVINFO="$PWD/$info"
#echo "CONVINFO: $CONVINFO"
#info=`sh pickinfo.sh $analdate ozinfo`
#export OZINFO="$PWD/$info"
#echo "OZINFO: $OZINFO"
#export SATINFO=$datapath/$analdate/satinfo
#sh create_satinfo.sh $analdate > $SATINFO
#cd ..

#   Set CONVINFO
if [[  "$analdate" -ge 2020091612 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_convinfo.txt.2020091612
elif [[  "$analdate" -ge 2020091612 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_convinfo.txt.2020052612
elif [[  "$analdate" -ge 2020040718 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_convinfo.txt.2020041718
elif [[  "$analdate" -ge 2019110706 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_convinfo.txt.2019110706
elif [[  "$analdate" -ge 2019021900 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_convinfo.txt.2019021900
elif [[ "$analdate" -ge "2018022818" ]]; then
    export CONVINFO=$fixgsi/fv3_historical/global_convinfo.txt.2018022818
elif [[ "$analdate" -ge "2018010512" ]]; then
    export CONVINFO=$fixgsi/fv3_historical/global_convinfo.txt.2018010512
elif [[ "$analdate" -ge "2017071912" ]]; then
    export CONVINFO=$fixgsi/fv3_historical/global_convinfo.txt.2017071912
elif [[ "$analdate" -ge "2016031512" ]]; then
    export CONVINFO=$fixgsi/fv3_historical/global_convinfo.txt.2016031512
elif [[ "$analdate" -ge "2014041400" ]]; then
    export CONVINFO=$fixgsi/fv3_historical/global_convinfo.txt.2014041400
else
    echo "no convinfo found"
    exit 1
fi

#   Set OZINFO
if [[  "$analdate" -ge 2020011806 ]]; then
    export OZINFO=$fixgsi/gfsv16_historical/global_ozinfo.txt.2020011806
elif [[  "$analdate" -ge 2020011600 ]]; then
    export OZINFO=$fixgsi/gfsv16_historical/global_ozinfo.txt.2020011600
elif [[  "$analdate" -ge 2020011600 ]]; then
    export OZINFO=$fixgsi/gfsv16_historical/global_ozinfo.txt.2020021900
elif [[  "$analdate" -ge 2020011806 ]]; then
    export CONVINFO=$fixgsi/gfsv16_historical/global_ozinfo.txt.2020011806
elif [[ "$analdate" -ge "2020011806" ]]; then
    export OZINFO=$fixgsi/fv3_historical/global_ozinfo.txt.2020011806
elif [[ "$analdate" -ge "2020011600" ]]; then
    export OZINFO=$fixgsi/fv3_historical/global_ozinfo.txt.2020011600
elif [[ "$analdate" -ge "2018110700" ]]; then
    export OZINFO=$fixgsi/fv3_historical/global_ozinfo.txt.2018110700
elif [[ "$analdate" -ge "2015110500" ]]; then
    export OZINFO=$fixgsi/fv3_historical/global_ozinfo.txt.2015110500
else
    echo "no ozinfo found"
    exit 1
fi

#   Set SATINFO
if [[ "$analdate" -ge "2020022012" ]]; then
    export SATINFO=$fixgsi/gfsv16_historical/global_satinfo.txt.2020022012
elif [[ "$analdate" -ge "2019110706" ]]; then
    export SATINFO=$fixgsi/gfsv16_historical/global_satinfo.txt.2019110706
elif [[ "$analdate" -ge "2019021900" ]]; then
    export SATINFO=$fixgsi/gfsv16_historical/global_satinfo.txt.2019021900
elif [[ "$analdate" -ge "2018053012" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2018053012
elif [[ "$analdate" -ge "2018021212" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2018021212
elif [[ "$analdate" -ge "2017103118" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2017103118
elif [[ "$analdate" -ge "2017031612" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2017031612
elif [[ "$analdate" -ge "2017030812" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2017030812
elif [[ "$analdate" -ge "2016110812" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2016110812
elif [[ "$analdate" -ge "2016090912" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2016090912
elif [[ "$analdate" -ge "2016020312" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2016020312
elif [[ "$analdate" -ge "2016011912" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2016011912
elif [[ "$analdate" -ge "2015111012" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2015111012
elif [[ "$analdate" -ge "2015100118" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2015100118
elif [[ "$analdate" -ge "2015070218" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2015070218
elif [[ "$analdate" -ge "2015011412" ]]; then
    export SATINFO=$fixgsi/fv3_historical/global_satinfo.txt.2015011412
else
    echo "no satinfo found"
    exit 1
fi

fi

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

# if nanals2>0, extend nanals2 members out to FHMAX_LONGER
# but only at 02,08,14,20UTC (for comparison with 6-h cycled system)
if [ $hr = "02" ] || [ $hr = "08" ] || [ $hr = "14" ] || [ $hr = "20"]; then
export nanals2=80
echo "will run $nanals2 members out to hour $FHMAX_LONGER"
else
export nanals2=-1
echo "no longer forecast extension"
fi

export PREINP="${RUN}.t${hr}z."
export PREINP1="${RUN}.t${hrp1}z."
export PREINPm1="${RUN}.t${hrm1}z."

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
   fh=$FHMIN
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
   export cold_start_bias "false"
fi

# use ensmean mean background for 3dvar analysis/observer calculatino
export charnanal='control' 
export charnanal2='ensmean'
export lobsdiag_forenkf='.true.'
export skipcat="false"
# run Var analysis
# symlink ens mean backgrounds to "control"
fh=$FHMIN
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
sh ${enkfscripts}/run_gsianal.sh > ${current_logdir}/run_gsianal.out 2>&1
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
sh ${enkfscripts}/runenkf.sh > ${current_logdir}/run_enkf.out 2>&1
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

# blend enkf mean and 3dvar increments, recenter ensemble
if [ $recenter_anal == "true" ]; then
   if [ $hybgain == "true" ]; then 
       if [ $alpha -gt 0 ]; then
       # hybrid gain
       echo "$analdate blend enkf and 3dvar increments `date`"
       sh ${enkfscripts}/blendinc.sh > ${current_logdir}/blendinc.out 2>&1
       blendinc_done=`cat ${current_logdir}/blendinc.log`
       if [ $blendinc_done == 'yes' ]; then
         echo "$analdate increment blending/recentering completed successfully `date`"
       else
         echo "$analdate increment blending/recentering did not complete successfully, exiting `date`"
         exit 1
       fi
       fi
   else
      # hybrid covariance
      export fileprefix="sanl"
      export charnanal="control"
      echo "$analdate recenter enkf analysis ensemble around control analysis `date`"
      sh ${enkfscripts}/recenter_ens.sh > ${current_logdir}/recenter_ens_anal.out 2>&1
      recenter_done=`cat ${current_logdir}/recenter.log`
      if [ $recenter_done == 'yes' ]; then
        echo "$analdate recentering enkf analysis completed successfully `date`"
      else
        echo "$analdate recentering enkf analysis did not complete successfully, exiting `date`"
        exit 1
      fi
   fi
fi

# for passive (replay) cycling of control forecast, optionally run GSI observer
# on control forecast background (diag files saved with 'control' suffix)
if [ $replay_controlfcst == 'true' ] && [ $replay_run_observer == "true" ]; then
   export charnanal='control' 
   export charnanal2='control' 
   export lobsdiag_forenkf='.false.'
   export skipcat="false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer.out 2>&1
   # once observer has completed, check log files.
   gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $gsi_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
fi

# run gsi observer on ensemble mean forecast extension
if [ $nanals2 -gt 0 ] && [ -s $datapath2/sfg2_${analdate}_fhr${FHMAX_LONGER}_ensmean ]; then
   # symlink ensmean files (fhr12_ensmean --> fhr06_ensmean2, etc)
   fh=$FHMAX
   while [ $fh -le $FHMAX_LONGER ]; do
     fhr=`printf %02i $fh`
     fh2=`expr $fh - $ANALINC`
     fhr2=`printf %02i $fh2`
     /bin/ln -fs ${datapath2}/sfg2_${analdate}_fhr${fhr}_ensmean ${datapath2}/sfg_${analdate}_fhr${fhr2}_ensmean2
     /bin/ln -fs ${datapath2}/bfg2_${analdate}_fhr${fhr}_ensmean ${datapath2}/bfg_${analdate}_fhr${fhr2}_ensmean2
     fh=$((fh+FHOUT))
   done
   export charnanal='ensmean2' 
   export charnanal2='ensmean2' 
   export lobsdiag_forenkf='.false.'
   export skipcat="false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsiobserver.out 2>&1
   # once observer has completed, check log files.
   gsi_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $gsi_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
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

echo "$analdate run enkf ens first guess `date`"
sh ${enkfscripts}/run_fg_ens.sh > ${current_logdir}/run_fg_ens.out  2>&1
ens_done=`cat ${current_logdir}/run_fg_ens.log`
if [ $ens_done == 'yes' ]; then
  echo "$analdate enkf first-guess completed successfully `date`"
else
  echo "$analdate enkf first-guess did not complete successfully, exiting `date`"
  exit 1
fi

if [ $cold_start == 'false' ]; then

# cleanup
if [ $do_cleanup == 'true' ]; then
   sh ${enkfscripts}/clean.sh > ${current_logdir}/clean.out 2>&1
fi # do_cleanup = true

wait # wait for backgrounded processes to finish

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
#sbatch --export=ALL job_hpss.sh
sbatch --export=machine=${machine},analdate=${analdate},datapath2=${datapath2},hsidir=${hsidir},save_hpss_full=${save_hpss_full},save_hpss_subset=${save_hpss_subset} job_hpss.sh

fi # skip to here if cold_start = true

echo "$analdate all done"

# next analdate: increment by $ANALINC
export analdate=`${incdate} $analdate $ANALINC`

echo "export analdate=${analdate}" > $startupenv
echo "export analdate_end=${analdate_end}" >> $startupenv
echo "export fg_only=false" > $datapath/fg_only.sh
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
      cat ${machine}_preamble config.sh > job.sh
      sbatch --export=ALL job.sh
   fi
fi

exit 0
