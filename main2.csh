# main driver script
# single resolution hybrid using jacobian in the EnKF

# allow this script to submit other scripts on WCOSS
unsetenv LSB_SUB_RES_REQ 

source $datapath/fg_only.csh # define fg_only variable.
echo "nodes = $NODES"

setenv startupenv "${datapath}/analdate.csh"
source $startupenv

# add SATINFO here (instead of submit.sh) since it depends on analysis time.
#setenv SATINFO ${obs_datapath}/bufr_${analdate}/global_satinfo.txt

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
# set environment analdate
setenv datapath2 "${datapath}/${analdate}/"
/bin/cp -f ${ANAVINFO_ENKF} ${datapath2}/anavinfo

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

if ($fg_only == 'false' && $readin_localization == ".true.") then
/bin/rm -f $datapath2/hybens_info
/bin/rm -f $datapath2/hybens_smoothinfo
if ( $?HYBENSINFO ) then
   /bin/cp -f ${HYBENSINFO} ${datapath2}/hybens_info
endif
if ( $?HYBENSMOOTH ) then
   /bin/cp -f ${HYBENSMOOTH} $datapath2/hybens_smoothinfo
endif
endif

setenv PREINP "${RUN}.t${hr}z."
setenv PREINP1 "${RUN}.t${hrp1}z."
setenv PREINPm1 "${RUN}.t${hrm1}z."

if ($fg_only ==  'false') then

echo "$analdate starting ens mean computation `date`"
csh ${enkfscripts}/compute_ensmean_fcst.csh >&!  ${current_logdir}/compute_ensmean_fcst.out
echo "$analdate done computing ensemble mean `date`"

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
   set fh=0
   while ($fh <= $FHMAX)
     set fhr=`printf %02i $fh`
     sh ${enkfscripts}/adjustps.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} >&! ${current_logdir}/adjustps.out
     @ fh = $fh + $FHOUT
   end
   echo "$analdate done adjusting orog/ps of control forecast on ens grid `date`"
endif

# for pure enkf or if replay cycle used for control forecast, symlink
# ensmean files to 'control'
if ($controlfcst == 'false' || $replay_controlfcst == 'true') then
   # single res hybrid, just symlink ensmean to control (no separate control forecast)
   set fh=0
   while ($fh <= $FHMAX)
     set fhr=`printf %02i $fh`
     ln -fs $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_control
     ln -fs $datapath2/bfg_${analdate}_fhr${fhr}_ensmean $datapath2/bfg_${analdate}_fhr${fhr}_control
     @ fh = $fh + $FHOUT
   end
endif

# if ${datapathm1}/cold_start_bias exists, GSI run in 'observer' mode
# to generate diag_rad files to initialize angle-dependent 
# bias correction.
if ( -f ${datapathm1}/cold_start_bias ) then
   setenv cold_start_bias "true"
else
   setenv cold_start_bias "false"
endif

set totcores=$cores
set totnodes=$NODES
setenv cores `expr $totcores \/ 2`
setenv NODES `expr $totnodes \/ 2`
if ($machine == 'theia') then
   pushd $datapath2
   split -d -l $cores $PBS_NODEFILE
   /bin/mv -f x00 hostfile1
   /bin/mv -f x01 hostfile2
   popd
endif

# run enkf and hybrid concurrently, each on half of available cores
if ($machine == 'theia') then
  setenv hostfilein ${datapath2}/hostfile1
endif
csh ${enkfscripts}/drive_enkf.csh >&! ${current_logdir}/drive_enkf.out &
if ($machine == 'theia') then
  setenv hostfilein ${datapath2}/hostfile2
endif
echo "$analdate run hybrid `date`"
csh ${enkfscripts}/run_hybridanal.csh >&! ${current_logdir}/run_gsi_hybrid.out  &
wait
setenv NODES $totnodes
setenv cores $totcores

# check log files.
set enkf_done=`cat ${current_logdir}/run_enkf.log`
if ($enkf_done == 'yes') then
  echo "$analdate enkf analysis completed successfully `date`"
else
  echo "$analdate enkf analysis did not complete successfully, exiting `date`"
  exit 1
endif
set hybrid_done=`cat ${current_logdir}/run_gsi_hybrid.log`
if ($hybrid_done == 'yes') then
  echo "$analdate hybrid analysis completed successfully `date`"
else
  echo "$analdate hybrid analysis did not complete successfully, exiting `date`"
  exit 1
endif

# compute ensemble mean analyses.
echo "$analdate starting ens mean analysis computation `date`"
csh ${enkfscripts}/compute_ensmean_enkf.csh >&!  ${current_logdir}/compute_ensmean_anal.out
echo "$analdate done computing ensemble mean analyses `date`"

# recenter enkf analyses around control analysis
if ($controlanal == 'true' && $recenter_anal == 'true') then
   echo "$analdate recenter enkf analysis ensemble around control analysis `date`"
   csh ${enkfscripts}/recenter_ens_anal.csh >&! ${current_logdir}/recenter_ens_anal.out 
   set recenter_done=`cat ${current_logdir}/recenter_ens.log`
   if ($recenter_done == 'yes') then
     echo "$analdate recentering enkf analysis completed successfully `date`"
   else
     echo "$analdate recentering enkf analysis did not complete successfully, exiting `date`"
     exit 1
   endif
endif

endif # skip to here if fg_only = true or fg_only == true

if ($controlfcst == 'true') then
    echo "$analdate run high-res control first guess `date`"
    csh ${enkfscripts}/run_fg_control.csh  >&! ${current_logdir}/run_fg_control.out  
    set control_done=`cat ${current_logdir}/run_fg_control.log`
    if ($control_done == 'yes') then
      echo "$analdate high-res control first-guess completed successfully `date`"
    else
      echo "$analdate high-res control did not complete successfully, exiting `date`"
      exit 1
    endif
endif
echo "$analdate run enkf ens first guess `date`"
csh ${enkfscripts}/run_fg_ens.csh  >>& ${current_logdir}/run_fg_ens.out  
set ens_done=`cat ${current_logdir}/run_fg_ens.log`
if ($ens_done == 'yes') then
  echo "$analdate enkf first-guess completed successfully `date`"
else
  echo "$analdate enkf first-guess did not complete successfully, exiting `date`"
  exit 1
endif

if ($fg_only == 'false') then

# cleanup
if ($do_cleanup == 'true') then
echo "clean up files `date`"
cd $datapath2

# move every member files to a temp dir.
/bin/rm -rf fgens fgens2
mkdir fgens
mkdir fgens2
/bin/rm -f mem*/*nc mem*/*txt mem*/*grb mem*/*dat 
/bin/mv -f mem* fgens
/bin/mv -f sfg*mem* fgens2
/bin/mv -f bfg*mem* fgens2
/bin/rm -f fgens2/*fhr00* fgens2/*orig
/bin/cp -f sfg*control fgens2
/bin/cp -f bfg*control fgens2
echo "files moved to fgens, fgens2 `date`"
if ( ! $?NOSAT ) then
# only save control and spread diag files.
/bin/rm -rf diag*ensmean.nc4
# only save conventional diag files
mkdir diagsavdir
/bin/mv -f diag*conv*control*nc4 diag*conv*spread*nc4 diagsavdir
/bin/rm -f diag*control*nc4 diag*spread*nc4
/bin/rm -f diagsavdir/diag*conv_gps*
/bin/mv -f diagsavdir/diag*nc4 .
/bin/rm -rf diagsavdir
endif

/bin/rm -f hostfile*
/bin/rm -f fort*
/bin/rm -f *log
/bin/rm -f *lores *mem*orig
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
/bin/rm -rf hybridtmp* gsitmp* gfstmp* nodefile* machinefile*
echo "unwanted files removed `date`"
endif # do_cleanup = true

wait # wait for backgrounded processes to finish

# only save full ensemble data to hpss if checkdate.py returns 0
# a subset will be saved if save_hpss_subset="true"
set date_check=`python ${homedir}/checkdate.py ${analdate}`
if ($date_check == 0) then
  setenv save_hpss "true"
else
  setenv save_hpss "false"
endif
cd $homedir
cat ${machine}_preamble_hpss hpss.sh >! job_hpss.sh
if ($machine == 'wcoss') then
   bsub -env "all" < job_hpss.sh
else if ($machine == 'gaea') then
   msub -V job_hpss.sh
else if ($machine == 'cori') then
   sbatch --export=ALL job_hpss.sh
else
   qsub -V job_hpss.sh
endif

if ($run_long_fcst == "true") then
   if ($hr == "00" || $hr == "12") then
     cat ${machine}_preamble_longfcst run_long_fcst.sh >! job_longfcst.sh
     if ($machine == 'wcoss') then
         bsub -env "all" < job_longfcst.sh
     else if ($machine == 'gaea') then
         msub -V job_longfcst.sh
     else if ($machine == 'cori') then
         sbatch --export=ALL job_longfcst.sh
     else
         qsub -V job_longfcst.sh
     endif
   endif
endif

endif # skip to here if fg_only = true

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
