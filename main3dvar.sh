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

cd build_gsinfo
export SATINFO=$datapath/$analdate/satinfo
export CONVINFO=$datapath/$analdate/convinfo
export OZINFO=$datapath/$analdate/ozinfo
sh create_satinfo.sh $analdate > $SATINFO
sh create_convinfo.sh $analdate > $CONVINFO
sh create_ozinfo.sh $analdate > $OZINFO
cd ..

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

export PREINP="${RUN}.t${hr}z."
export PREINP1="${RUN}.t${hrp1}z."
export PREINPm1="${RUN}.t${hrm1}z."

if [ $fg_only ==  'false' ]; then

# if ${datapathm1}/cold_start_bias exists, GSI run in 'observer' mode
# to generate diag_rad files to initialize angle-dependent 
# bias correction.
if [ -f ${datapathm1}/cold_start_bias ]; then
   export cold_start_bias="true"
else
   export cold_start_bias "false"
fi

type="3DVar"
export charnanal='control' 
export charnanal2='control'
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

fi # skip to here if fg_only = true

echo "$analdate run control first guess `date`"
sh ${enkfscripts}/run_fg_control.sh  > ${current_logdir}/run_fg_control.out  2>&1
control_done=`cat ${current_logdir}/run_fg_control.log`
if [ $control_done == 'yes' ]; then
  echo "$analdate control first-guess completed successfully `date`"
else
  echo "$analdate control did not complete successfully, exiting `date`"
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
echo "unset skip_calc_increment" >> $datapath/fg_only.sh

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
