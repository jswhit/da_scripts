# main driver script
# single resolution hybrid using jacobian in the EnKF

# allow this script to submit other scripts on WCOSS
unsetenv LSB_SUB_RES_REQ 

source $datapath/fg_only.csh # define fg_only variable.
echo "nodes = $NODES"

setenv startupenv "${datapath}/analdate.csh"
source $startupenv

# if SATINFO in obs dir, use it
if ( -s ${obs_datapath}/bufr_${analdate}/global_satinfo.txt) then
   setenv SATINFO ${obs_datapath}/bufr_${analdate}/global_satinfo.txt
endif

#------------------------------------------------------------------------
mkdir -p $datapath

echo "BaseDir: ${basedir}"
echo "EnKFBin: ${enkfbin}"
echo "DataPath: ${datapath}"

############################################################################
# Main Program
# Please do not edit the code below; it is not recommended except lines relevant to getsfcensmean.csh.

env
echo "starting the cycle"

# substringing to get yr, mon, day, hr info
setenv yr `echo $analdate | cut -c1-4`
setenv mon `echo $analdate | cut -c5-6`
setenv day `echo $analdate | cut -c7-8`
setenv hr `echo $analdate | cut -c9-10`
setenv ANALHR $hr
setenv datapath2 "${datapath}/${analdate}/"
/bin/cp -f ${ANAVINFO_ENKF} ${datapath2}/anavinfo

# setup node parameters used in recenter_ens_anal.csh and compute_ensmean_fcst.csh
setenv mpitaskspernode `python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if ($mpitaskspernode < 1) setenv mpitaskspernode 1
setenv OMP_NUM_THREADS `expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
setenv nprocs $nanals
if ($machine == 'theia') then
    # HOSTFILE is machinefile to use for programs that require $nanals tasks.
    # if enough cores available, just one core on each node.
    # NODEFILE is machinefile containing one entry per node.
    setenv HOSTFILE $datapath2/machinesx
    setenv NODEFILE $datapath2/nodefile
    cat $PBS_NODEFILE | uniq > $NODEFILE
    if ($NODES >= $nanals) then
      ln -fs $NODEFILE $HOSTFILE
    else
      # otherwise, leave as many cores empty as possible
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} >&! $HOSTFILE
    endif
    /bin/cp -f $PBS_NODEFILE $datapath2/pbs_nodefile
endif

# current analysis time.
setenv analdate $analdate
# previous analysis time.
set FHOFFSET=`expr $ANALINC \/ 2`
setenv analdatem1 `${incdate} $analdate -$ANALINC`
# next analysis time.
setenv analdatep1 `${incdate} $analdate $ANALINC`
# beginning of current assimilation window
setenv analdatem3 `${incdate} $analdate -$FHOFFSET`
# beginning of next assimilation window
setenv analdatep1m3 `${incdate} $analdate $FHOFFSET`
setenv hrp1 `echo $analdatep1 | cut -c9-10`
setenv hrm1 `echo $analdatem1 | cut -c9-10`
setenv hr `echo $analdate | cut -c9-10`
setenv datapathp1 "${datapath}/${analdatep1}/"
setenv datapathm1 "${datapath}/${analdatem1}/"
mkdir -p $datapathp1
setenv CDATE $analdate

date
echo "analdate minus 1: $analdatem1"
echo "analdate: $analdate"
echo "analdate plus 1: $analdatep1"

# make log dir for analdate
setenv current_logdir "${datapath2}/logs"
echo "Current LogDir: ${current_logdir}"
mkdir -p ${current_logdir}

setenv PREINP "${RUN}.t${hr}z."
setenv PREINP1 "${RUN}.t${hrp1}z."
setenv PREINPm1 "${RUN}.t${hrm1}z."

if ($fg_only ==  'false') then

# change orography in high-res control forecast nemsio file so it matches enkf ensemble, adjust
# surface pressure accordingly.
if ($controlfcst == 'true') then
   if ($replay_controlfcst == 'true') then
     # sfg*control2 only used to compute IAU forcing
     set charnanal='control2'
   else
     set charnanal='control'
   endif
   echo "$analdate adjust orog/ps of control forecast on ens grid `date`"
   /bin/rm -f ${current_logdir}/adjustps.out
   touch ${current_logdir}/adjustps.out
   set fh=0
   while ($fh <= $FHMAX)
     set fhr=`printf %02i $fh`
     sh ${enkfscripts}/adjustps.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} >&! ${current_logdir}/adjustps.out
     @ fh = $fh + $FHOUT
   end
   echo "$analdate done adjusting orog/ps of control forecast on ens grid `date`"
endif

# for passive (replay) cycling of control forecast, optionally run GSI observer
# on control forecast background (diag files saved with 'control2' suffix)
setenv charnanal 'control2'
setenv charnanal2 'control2'
setenv lobsdiag_forenkf '.false.'
setenv skipcat "false"
echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
csh ${enkfscripts}/run_gsiobserver.csh >&! ${current_logdir}/run_gsi_observer2.out 
# once observer has completed, check log files.
set hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
if ($hybrid_done == 'yes') then
  echo "$analdate gsi observer completed successfully `date`"
else
  echo "$analdate gsi observer did not complete successfully, exiting `date`"
  exit 1
endif

endif # skip to here if fg_only = true or fg_only == true

echo "$analdate run high-res control first guess `date`"
csh ${enkfscripts}/run_fg_control.csh  >&! ${current_logdir}/run_fg_control.out  
set control_done=`cat ${current_logdir}/run_fg_control.log`
if ($control_done == 'yes') then
  echo "$analdate high-res control first-guess completed successfully `date`"
else
  echo "$analdate high-res control did not complete successfully, exiting `date`"
  exit 1
endif

if ($fg_only == 'false') then

# cleanup
if ($do_cleanup == 'true') then
   csh ${enkfscripts}/clean_replay.csh >&! ${current_logdir}/clean.out
endif # do_cleanup = true

wait # wait for backgrounded processes to finish

# only save full ensemble data to hpss if checkdate.py returns 0
# a subset will be saved if save_hpss_subset="true" and save_hpss="true"
#set date_check=`python ${homedir}/checkdate.py ${analdate}`
#if ($date_check == 0) then
#  setenv save_hpss_full "true"
#else
#  setenv save_hpss_full "false"
#endif
#cd $homedir
#if ( $save_hpss == "true" ) then
#cat ${machine}_preamble_hpss hpss.sh >! job_hpss.sh
#if ($machine == 'wcoss') then
#   bsub -env "all" < job_hpss.sh
#else if ($machine == 'gaea') then
#   msub -V job_hpss.sh
#else if ($machine == 'cori') then
#   sbatch --export=ALL job_hpss.sh
#else
#   qsub -V job_hpss.sh
#endif
#endif
#
#if ($run_long_fcst == "true") then
#   if ($hr == "00") then
#   #if ($hr == "00" || $hr == "12") then
#     cat ${machine}_preamble_longfcst run_long_fcst.sh >! job_longfcst.sh
#     if ($machine == 'wcoss') then
#         bsub -env "all" < job_longfcst.sh
#     else if ($machine == 'gaea') then
#         msub -V job_longfcst.sh
#     else if ($machine == 'cori') then
#         sbatch --export=ALL job_longfcst.sh
#     else
#         qsub -V job_longfcst.sh
#     endif
#   endif
#endif

endif # skip to here if fg_only = true

echo "$analdate all done"

# next analdate: increment by $ANALINC
setenv analdate `${incdate} $analdate $ANALINC`

echo "setenv analdate ${analdate}" >! $startupenv
echo "setenv analdate_end ${analdate_end}" >> $startupenv
echo "setenv fg_only false" >! $datapath/fg_only.csh

cd $homedir

if ( ${analdate} <= ${analdate_end}  && ${resubmit} == 'true') then
   echo "current time is $analdate"
   if ($resubmit == "true") then
      echo "resubmit script"
      echo "machine = $machine"
      cat ${machine}_preamble config.sh >! job.sh
      if ($machine == 'wcoss') then
          bsub < job.sh
      else if ($machine == 'gaea') then
          msub job.sh
      else if ($machine == 'cori') then
          sbatch job.sh
      else
          qsub job.sh
      endif
   endif
endif

exit 0
