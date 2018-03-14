#!/bin/csh
# do hybrid analysis.

setenv CO2DIR $fixgsi

setenv charnanal 'control'
setenv charnanal2 'control'
setenv lobsdiag_forenkf '.false.'
setenv skipcat "false"

if ($machine == 'theia') then
   if (! $?hostfilein) then
     setenv hostfilein $PBS_NODEFILE
     setenv NODEFILE $datapath2/nodefile_envar
   endif
   cat $hostfilein | uniq > $NODEFILE
endif

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

if ($cleanup_controlanl == 'true') then
   /bin/rm -f ${SIGANL06}
   /bin/rm -f ${datapath2}/diag*control
endif

set niter=1
set alldone='no'
if ( -s $SIGANL06 && -s $BIASO && -s $SATANGO) set alldone='yes'

while ($alldone == 'no' && $niter <= $nitermax)

setenv JCAP_A $JCAP
setenv JCAP_B $JCAP
setenv HXONLY 'NO'
setenv VERBOSE YES  
setenv OMP_NUM_THREADS $gsi_control_threads
setenv OMP_STACKSIZE 2048M
setenv nprocs `expr $cores \/ $OMP_NUM_THREADS`
setenv mpitaskspernode `expr $corespernode \/ $OMP_NUM_THREADS`
if ($machine == 'theia') then
   setenv KMP_AFFINITY scatter
   if ($OMP_NUM_THREADS > 1) then
      setenv HOSTFILE $datapath2/machinefile_envar
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

setenv tmpdir $datapath2/hybridtmp$$
if ($cold_start_bias == "true") then
    setenv lread_obs_save ".true."
    setenv lread_obs_skip ".false."
    echo "${analdate} compute gsi observer to cold start bias correction"
    setenv HXONLY 'YES'
    /bin/rm -rf $tmpdir
    mkdir -p $tmpdir
    time sh ${enkfscripts}/${rungsi}
    /bin/rm -rf $tmpdir
    if ( ! -s ${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal}.nc4 ) then
       echo "gsi observer step failed"
       exit 1
    endif
endif
setenv lread_obs_save ".false."
setenv lread_obs_skip ".false."
setenv HXONLY 'NO'
if ( -s $SIGANL06 ) then
  echo "gsi hybrid already completed"
  echo "yes" >&! ${current_logdir}/run_gsi_hybrid.log
  exit 0
endif
echo "${analdate} compute gsi hybrid analysis increment `date`"
/bin/rm -rf $tmpdir
mkdir -p $tmpdir
/bin/cp -f $datapath2/hybens_info $tmpdir
time sh ${enkfscripts}/${rungsi}
if ($cold_start_bias == "true") then
  setenv GBIAS ${datapath2}/${PREINP}abias
  setenv GBIAS_PC ${datapath2}/${PREINP}abias_pc
  setenv GBIASAIR ${datapath2}/${PREINP}abias_air
  echo "${analdate} re-compute gsi hybrid analysis increment `date`"
  time sh ${enkfscripts}/${rungsi}
endif
if ($status != 0) then
  echo "gsi hybrid analysis did not complete sucessfully"
  set exitstat=1
else
  if ( ! -s $SIGANL06 ) then
    echo "gsi hybrid analysis did not complete sucessfully"
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
    echo "Tried ${nitermax} times and to do gsi hybrid analysis and failed"
    echo "no" >&! ${current_logdir}/run_gsi_hybrid.log
else
    echo "yes" >&! ${current_logdir}/run_gsi_hybrid.log
    /bin/rm -rf $tmpdir
endif
exit 0
