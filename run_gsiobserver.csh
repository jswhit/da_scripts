#!/bin/csh
# do hybrid observer.

if ($cold_start_bias == "true") setenv NOSAT YES

if ( ! $?charnanal2 ) setenv charnanal2 $charnanal

if ( ! $?SLURM_JOB_ID && $machine == 'theia') then
   if (! $?hostfilein) then
     setenv hostfilein $PBS_NODEFILE
     setenv NODEFILE $datapath2/nodefile_observer
   endif
   cat $hostfilein | uniq > $NODEFILE
endif

setenv CO2DIR $fixgsi

# charanal is an env var set in parent script
setenv SIGANL03 ${datapath2}/sanl_${analdate}_fhr03_${charnanal}
setenv SIGANL04 ${datapath2}/sanl_${analdate}_fhr04_${charnanal}
setenv SIGANL05 ${datapath2}/sanl_${analdate}_fhr05_${charnanal}
setenv SIGANL06 ${datapath2}/sanl_${analdate}_fhr06_${charnanal}
setenv SIGANL07 ${datapath2}/sanl_${analdate}_fhr07_${charnanal}
setenv SIGANL08 ${datapath2}/sanl_${analdate}_fhr08_${charnanal}
setenv SIGANL09 ${datapath2}/sanl_${analdate}_fhr09_${charnanal}
setenv BIASO ${datapath2}/${PREINP}abias 
setenv BIASO_PC ${datapath2}/${PREINP}abias_pc 
setenv SATANGO ${datapath2}/${PREINP}satang
setenv DTFANL ${datapath2}/${PREINP}dtfanl.nc
echo "NOCONV:" $NOCONV
if ($skipcat == 'false') then
   if ($NOCONV == 'YES') then
     set diagfile=${datapath2}/diag_amsua_n15_ges.${analdate}_${charnanal2}.nc4
   else
     set diagfile=${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal2}.nc4
   endif
else
   if ($NOCONV == 'YES') then
     set diagfile=${datapath2}/gsitmp_${charnanal2}/pe0000.amsua_n15_01.nc4
   else
     set diagfile=${datapath2}/gsitmp_${charnanal2}/pe0000.conv_uv_01.nc4
   endif
endif
echo "skipcat $skipcat diagfile $diagfile"

if ($cleanup_observer == "true") then
  if ($skipcat == 'false') then
     echo "removing diag files"
     /bin/rm -f ${datapath2}/diag*${charnanal2}*nc4
  else
     echo "removing ${datapath2}/gsitmp_${charnanal2}"
     /bin/rm -rf ${datapath2}/gsitmp_${charnanal2}
  endif
endif
ls -l $diagfile

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
if ( ! $?SLURM_JOB_ID && $machine == 'theia') then
   setenv KMP_AFFINITY scatter
   if ($OMP_NUM_THREADS > 1) then
      setenv HOSTFILE $datapath2/machinefile_observer
      /bin/rm -f $HOSTFILE
      awk "NR%${gsi_control_threads} == 1" ${hostfilein} >&! $HOSTFILE
   else
      setenv HOSTFILE $hostfilein
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
    setenv GBIAS ${biascorrdir}/${analdate}//${PREINP}abias
    setenv GBIAS_PC ${biascorrdir}/${analdate}//${PREINP}abias_pc
    setenv GBIASAIR ${biascorrdir}/${analdate}//${PREINP}abias_air
    setenv ABIAS ${biascorrdir}/${analdate}//${PREINP}abias
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
setenv tmpdir $datapath2/gsitmp_${charnanal2}
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
    if ($skipcat == "false") then
        /bin/rm -rf $tmpdir
    endif
endif
exit 0
