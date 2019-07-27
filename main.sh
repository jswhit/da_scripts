#!/bin/sh

# main driver script
# single resolution hybrid using jacobian in the EnKF

# allow this script to submit other scripts with LSF
unset LSB_SUB_RES_REQ 

echo "nodes = $NODES"

idate_job=1

while [ $idate_job -le ${ndates_job} ]; do

source $datapath/fg_only.sh # define fg_only variable.

export startupenv="${datapath}/analdate.sh"
source $startupenv

# if SATINFO in obs dir, use it
if [ -s ${obs_datapath}/bufr_${analdate}/global_satinfo.txt ]; then
   export SATINFO=${obs_datapath}/bufr_${analdate}/global_satinfo.txt
fi
export OZINFO=`sh ${enkfscripts}/pickinfo.sh ${analdate} ozinfo`
export CONVINFO=`sh ${enkfscripts}/pickinfo.sh ${analdate} convinfo`

#------------------------------------------------------------------------
mkdir -p $datapath

echo "BaseDir: ${basedir}"
echo "EnKFBin: ${enkfbin}"
echo "DataPath: ${datapath}"

############################################################################
# Main Program

env
echo "starting the cycle (${idate_job} out of ${ndates_job})"

# substringing to get yr, mon, day, hr info
export yr=`echo $analdate | cut -c1-4`
export mon=`echo $analdate | cut -c5-6`
export day=`echo $analdate | cut -c7-8`
export hr=`echo $analdate | cut -c9-10`
export ANALHR=$hr
# set environment analdate
export datapath2="${datapath}/${analdate}/"
/bin/cp -f ${ANAVINFO_ENKF} ${datapath2}/anavinfo

# setup node parameters used in blendinc.csh, recenter_ens_anal.csh and compute_ensmean_fcst.sh
export mpitaskspernode=`python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if [ $mpitaskspernode -lt 1 ]; then
  export mpitaskspernode 1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals


if [ -z $SLURM_JOB_ID ] && [ $machine == 'theia' ]; then
    # HOSTFILE is machinefile to use for programs that require $nanals tasks.
    # if enough cores available, just one core on each node.
    # NODEFILE is machinefile containing one entry per node.
    export HOSTFILE=$datapath2/machinesx
    export NODEFILE=$datapath2/nodefile
    cat $PBS_NODEFILE | uniq > $NODEFILE
    if [ $NODES -ge$nanals ]; then
      ln -fs $NODEFILE $HOSTFILE
    else
      # otherwise, leave as many cores empty as possible
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} > $HOSTFILE
    fi
    /bin/cp -f $PBS_NODEFILE $datapath2/pbs_nodefile
fi

# current analysis time.
export analdate=$analdate
# previous analysis time.
FHOFFSET=`expr $ANALINC \/ 2`
export analdatem1=`${incdate} $analdate -$ANALINC`
# next analysis time.
export analdatep1=`${incdate} $analdate $ANALINC`
# beginning of current assimilation window
export analdatem3=`${incdate} $analdate -$FHOFFSET`
# beginning of next assimilation window
export analdatep1m3=`${incdate} $analdate $FHOFFSET`
export hrp1=`echo $analdatep1 | cut -c9-10`
export hrm1=`echo $analdatem1 | cut -c9-10`
export hr=`echo $analdate | cut -c9-10`
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

if [ $fg_only == 'false' ]; then
/bin/rm -f $datapath2/hybens_info
/bin/rm -f $datapath2/hybens_smoothinfo
if [ ! -z $HYBENSINFO ]; then
   /bin/cp -f ${HYBENSINFO} ${datapath2}/hybens_info
fi
if [ ! -z $HYBENSMOOTH ];  then
   /bin/cp -f ${HYBENSMOOTH} $datapath2/hybens_smoothinfo
fi
fi

export PREINP="${RUN}.t${hr}z."
export PREINP1="${RUN}.t${hrp1}z."
export PREINPm1="${RUN}.t${hrm1}z."

if [ $fg_only ==  'false' ]; then

echo "$analdate starting ens mean computation `date`"
sh ${enkfscripts}/compute_ensmean_fcst.sh >  ${current_logdir}/compute_ensmean_fcst.out 2>&1
echo "$analdate done computing ensemble mean `date`"

# change orography in high-res control forecast nemsio file so it matches enkf ensemble,
# adjust surface pressure accordingly.
# this file only used to calculate analysis increment for replay
if [ $controlfcst == 'true' ] && [ $cleanup_ensmean == 'true' ]; then
   if [ $replay_controlfcst == 'true' ]; then
     # sfg*control2 only used to compute IAU forcing
     # and for gsi observer diagnostic calculation
     charnanal='control2'
   else
     charnanal='control'
   fi
   echo "$analdate adjust orog/ps of control forecast on ens grid `date`"
   /bin/rm -f ${current_logdir}/adjustps.out
   touch ${current_logdir}/adjustps.out
   fh=$FHMIN
   while [ $fh -le $FHMAX ]; do
     fhr=`printf %02i $fh`
     # run concurrently, wait
     # TODO: both these codes need to be generalized to handle arbitrary fields in nemsio
     if [ $LONB -eq $LONB_CTL ]; then
       # this requires reduced diag_table (diag_table_reduced)
       sh ${enkfscripts}/adjustps.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal}.chgres > ${current_logdir}/adjustps_${fhr}.out 2>&1 &
     else
       # this requires full diag_table (full EMC version)
       sh ${enkfscripts}/chgres.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal}.chgres > ${current_logdir}/chgres_${fhr}.out 2>&1 &
     fi
     fh=$((fh+FHOUT))
   done
   wait
   if [ $? -ne 0 ]; then
      echo "adjustps/chgres step failed, exiting...."
      exit 1
   fi
   echo "$analdate done adjusting orog/ps of control forecast on ens grid `date`"
fi

# for pure enkf or if replay cycle used for control forecast, symlink
# ensmean files to 'control'
if [ $controlfcst == 'false' ] || [ $replay_controlfcst == 'true' ]; then
   # single res hybrid, just symlink ensmean to control (no separate control forecast)
   fh=$FHMIN
   while [ $fh -le $FHMAX ]; do
     fhr=`printf %02i $fh`
     ln -fs $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_control
     ln -fs $datapath2/bfg_${analdate}_fhr${fhr}_ensmean $datapath2/bfg_${analdate}_fhr${fhr}_control
     fh=$((fh+FHOUT))
   done
fi

# if ${datapathm1}/cold_start_bias exists, GSI run in 'observer' mode
# to generate diag_rad files to initialize angle-dependent 
# bias correction.
if [ -f ${datapathm1}/cold_start_bias ]; then
   export cold_start_bias="true"
else
   export cold_start_bias "false"
fi

# do hybrid control analysis if controlanal=true
# uses control forecast background, except if replay_controlfcst=true
# ens mean background is used ("control" symlinked to "ensmean", control
# forecast uses "control2")
if [ $controlanal == 'true' ]; then
   if [ $replay_controlfcst == 'true' ] || [ $controlfcst == 'false' ]; then
      # use ensmean mean background if no control forecast is run, or 
      # control forecast is replayed to ens mean increment
      export charnanal='control'
      export charnanal2='ensmean'
      export lobsdiag_forenkf='.true.'
      export skipcat="false"
   else
      # use control forecast background if control forecast is run, and it is
      # not begin replayed to ensemble mean increment.
      export charnanal='control' # sfg files at ensemble resolution
      export charnanal2='control' # for diag files
      export lobsdiag_forenkf='.false.'
      export skipcat="false"
   fi
   if [ $hybgain == 'true' ]; then
      type='3DVar'
   else
      type='hybrid 4DEnVar'
   fi
   # run Var analysis
   echo "$analdate run $type `date`"
   sh ${enkfscripts}/run_hybridanal.sh > ${current_logdir}/run_gsi_hybrid.out 2>&1
   # once hybrid has completed, check log files.
   hybrid_done=`cat ${current_logdir}/run_gsi_hybrid.log`
   if [ $hybrid_done == 'yes' ]; then
     echo "$analdate $type analysis completed successfully `date`"
   else
     echo "$analdate $type analysis did not complete successfully, exiting `date`"
     exit 1
   fi
else
   # run gsi observer with ens mean fcst background, saving jacobian.
   # generated diag files used by EnKF. No control analysis.
   export charnanal='control' 
   export charnanal2='ensmean'
   export lobsdiag_forenkf='.true.'
   export skipcat="false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer.out 2>&1
   # once observer has completed, check log files.
   hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $hybrid_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
fi

# run enkf analysis.
echo "$analdate run enkf `date`"
if [ $skipcat == "true" ]; then
  # read un-concatenated pe files (set npefiles to number of mpi tasks used by gsi observer)
  export npefiles=`expr $cores \/ $gsi_control_threads`
else
  export npefiles=0
fi
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
echo "$analdate starting ens mean analysis computation `date`"
sh ${enkfscripts}/compute_ensmean_enkf.sh > ${current_logdir}/compute_ensmean_anal.out 2>&1
echo "$analdate done computing ensemble mean analyses `date`"

# recenter enkf analyses around control analysis
if [ $controlanal == 'true' ] && [ $recenter_anal == 'true' ]; then
   if [ $hybgain == 'true' ]; then
      if [ $alpha -gt 0 ]; then
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
      echo "$analdate recenter enkf analysis ensemble around control analysis `date`"
      sh ${enkfscripts}/recenter_ens_anal.sh > ${current_logdir}/recenter_ens_anal.out 2>&1
      recenter_done=`cat ${current_logdir}/recenter_ens.log`
      if [ $recenter_done == 'yes' ]; then
        echo "$analdate recentering enkf analysis completed successfully `date`"
      else
        echo "$analdate recentering enkf analysis did not complete successfully, exiting `date`"
        exit 1
      fi
   fi
fi

# for passive (replay) cycling of control forecast, optionally run GSI observer
# on control forecast background (diag files saved with 'control2' suffix)
if [ $controlfcst == 'true' ] && [ $replay_controlfcst == 'true' ] && [ $replay_run_observer == "true" ]; then
   export charnanal='control2' 
   export charnanal2='control2' 
   export lobsdiag_forenkf='.false.'
   export skipcat="false"
   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
   sh ${enkfscripts}/run_gsiobserver.sh > ${current_logdir}/run_gsi_observer2.out 2>&1
   # once observer has completed, check log files.
   hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
   if [ $hybrid_done == 'yes' ]; then
     echo "$analdate gsi observer completed successfully `date`"
   else
     echo "$analdate gsi observer did not complete successfully, exiting `date`"
     exit 1
   fi
fi

fi # skip to here if fg_only = true or fg_only == true

if [ $controlfcst == 'true' ]; then
    echo "$analdate run high-res control first guess `date`"
    sh ${enkfscripts}/run_fg_control.sh  > ${current_logdir}/run_fg_control.out  2>&1
    control_done=`cat ${current_logdir}/run_fg_control.log`
    if [ $control_done == 'yes' ]; then
      echo "$analdate high-res control first-guess completed successfully `date`"
    else
      echo "$analdate high-res control did not complete successfully, exiting `date`"
      exit 1
    fi
    # run longer forecast at 00UTC
    if [ $fg_only != "true" ] && [ $hr == '00' ] && [ $run_long_fcst == "true" ]; then
       echo "$analdate run high-res control long forecast `date`"
       sh ${enkfscripts}/run_long_fcst.sh > ${current_logdir}/run_long_fcst.out  2>&1
       control_done=`cat ${current_logdir}/run_long_fcst.log`
       if [ $control_done == 'yes' ]; then
         echo "$analdate high-res control long forecast completed successfully `date`"
       else
         echo "$analdate high-res control long forecast did not complete successfully `date`"
       fi
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

if [ $fg_only == 'false' ]; then

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
if [ ! -z $SLURM_JOB_ID ]; then
   cat ${machine}_preamble_hpss_slurm hpss.sh > job_hpss.sh
else
   cat ${machine}_preamble_hpss hpss.sh > job_hpss.sh
fi
if [ ! -z $SLURM_JOB_ID ];  then
   #sbatch --export=ALL job_hpss.sh
   sbatch --export=machine=${machine},analdate=${analdate},datapath2=${datapath2},hsidir=${hsidir},save_hpss_full=${save_hpss_full},save_hpss_subset=${save_hpss_subset} job_hpss.sh
elif [ $machine == 'wcoss' ]; then
   bsub -env "all" < job_hpss.sh
elif [ $machine == 'gaea' ]; then
   msub -V job_hpss.sh
else
   qsub -V job_hpss.sh
fi
fi

fi # skip to here if fg_only = true

echo "$analdate all done"

# next analdate: increment by $ANALINC
export analdate=`${incdate} $analdate $ANALINC`

echo "export analdate=${analdate}" > $startupenv
echo "export analdate_end=${analdate_end}" >> $startupenv
echo "export fg_only=false" > $datapath/fg_only.sh

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
      if [ ! -z $SLURM_JOB_ID ]; then
         cat ${machine}_preamble_slurm config.sh > job.sh
      else
         cat ${machine}_preamble config.sh > job.sh
      fi
      if [ ! -z $SLURM_JOB_ID ]; then
          sbatch --export=ALL job.sh
      elif [ $machine == 'wcoss' ]; then
          bsub < job.sh
      elif [ $machine == 'gaea' ]; then
          msub job.sh
      else
          qsub job.sh
      fi
   fi
fi

exit 0
