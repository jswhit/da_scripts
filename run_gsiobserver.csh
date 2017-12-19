#!/bin/csh
# do hybrid observer.

setenv CO2DIR $fixgsi

# charanal is an env var set in parent script
setenv SIGANL ${datapath2}/sanl_${analdate}_${charnanal}
setenv SIGANL03 ${datapath2}/sanl_${analdate}_fhr03_${charnanal}
setenv SIGANL04 ${datapath2}/sanl_${analdate}_fhr04_${charnanal}
setenv SIGANL05 ${datapath2}/sanl_${analdate}_fhr05_${charnanal}
setenv SIGANL06 ${datapath2}/sanl_${analdate}_fhr06_${charnanal}
setenv SIGANL07 ${datapath2}/sanl_${analdate}_fhr07_${charnanal}
setenv SIGANL08 ${datapath2}/sanl_${analdate}_fhr08_${charnanal}
setenv SIGANL09 ${datapath2}/sanl_${analdate}_fhr09_${charnanal}
setenv SFCANL ${datapath2}/sfcanl_${analdate}_${charnanal}
setenv SFCANLm3 ${datapath2}/sfcanl_${analdate}_fhr03_${charnanal}
setenv BIASO ${datapath2}/${PREINP}abias 
setenv BIASO_PC ${datapath2}/${PREINP}abias_pc 
setenv SATANGO ${datapath2}/${PREINP}satang
set diagfile=${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal}.nc4

if ($cleanup_observer == "true") then
  /bin/rm -f ${datapath2}/diag*${charnanal}*nc4
endif

set niter=1
set alldone='no'
if ( -s ${diagfile} ) set alldone='yes'

while ($alldone == 'no' && $niter <= $nitermax)

setenv JCAP_A $JCAP
setenv JCAP_B $JCAP
setenv VERBOSE YES  
setenv OMP_NUM_THREADS $gsi_control_threads
setenv OMP_STACKSIZE 2048M
setenv nprocs `expr $cores \/ $OMP_NUM_THREADS`
setenv mpitaskspernode `expr $corespernode \/ $OMP_NUM_THREADS`
if ($machine != 'wcoss') then
   setenv KMP_AFFINITY scatter
   if ($OMP_NUM_THREADS > 1) then
      setenv HOSTFILE $datapath2/machinefile_envar
      /bin/rm -f $HOSTFILE
      awk "NR%${gsi_control_threads} == 1" ${PBS_NODEFILE} >&! $HOSTFILE
   else
      setenv HOSTFILE $PBS_NODEFILE
   endif
   cat $HOSTFILE
   wc -l $HOSTFILE
   #setenv OMP_NUM_THREADS 1
endif
echo "running with $OMP_NUM_THREADS threads ..."

if ( ! $?biascorrdir ) then # cycled bias correction files
    setenv GBIAS ${datapathm1}/${PREINPm1}abias
    setenv GBIAS_PC ${datapathm1}/${PREINPm1}abias_pc
    setenv GBIASAIR ${datapathm1}/${PREINPm1}abias_air
    setenv ABIAS ${datapath2}/${PREINP}abias
else # externally specified bias correction files.
    setenv GBIAS ${biascorrdir}/${analdate}//${PREINPm1}abias
    setenv GBIAS_PC ${biascorrdir}/${analdate}//${PREINPm1}abias_pc
    setenv GBIASAIR ${biascorrdir}/${analdate}//${PREINPm1}abias_air
    setenv ABIAS ${biascorrdir}/${analdate}//${PREINPm1}abias
endif
setenv GSATANG $fixgsi/global_satangbias.txt # not used, but needs to exist

setenv lread_obs_save ".false."
setenv lread_obs_skip ".false."
setenv HXONLY 'YES'
if ( -s ${diagfile} ) then
  echo "gsi hybrid observer already completed"
  echo "yes" >&! ${current_logdir}/run_gsi_observer.log
  exit 0
endif
echo "${analdate} compute gsi hybrid observer `date`"
setenv tmpdir $datapath2/hybridtmp$$
/bin/rm -rf $tmpdir
mkdir -p $tmpdir
/bin/cp -f $datapath2/hybens_info $tmpdir
time sh ${enkfscripts}/${rungsi}

if ($status != 0) then
  echo "gsi hybrid observer did not complete sucessfully"
  set exitstat=1
else
  if ( ! -s ${diagfile} ) then
    ls -l ${diagfile}
    echo "gsi hybrid observer did not complete sucessfully"
    set exitstat=1
  else
    echo "gsi hybrid completed sucessfully"
    set exitstat=0
  endif
endif
/bin/rm -rf $tmpdir

if ($exitstat == 0) then
   set alldone='yes'
else
   echo "some files missing, try again .."
   @ niter = $niter + 1
endif
end

if($alldone == 'no') then
    echo "Tried ${nitermax} times and to do gsi hybrid observer and failed"
    echo "no" >&! ${current_logdir}/run_gsi_observer.log
else
    echo "yes" >&! ${current_logdir}/run_gsi_observer.log
endif
exit 0
