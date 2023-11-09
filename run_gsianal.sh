#!/bin/sh
# do hybrid analysis.

export CO2DIR=$fixgsi
export SIGANL03=${datapath2}/sanl_${analdate}_fhr03_${charnanal}
export SIGANL04=${datapath2}/sanl_${analdate}_fhr04_${charnanal}
export SIGANL05=${datapath2}/sanl_${analdate}_fhr05_${charnanal}
export SIGANL06=${datapath2}/sanl_${analdate}_fhr06_${charnanal}
export SIGANL07=${datapath2}/sanl_${analdate}_fhr07_${charnanal}
export SIGANL08=${datapath2}/sanl_${analdate}_fhr08_${charnanal}
export SIGANL09=${datapath2}/sanl_${analdate}_fhr09_${charnanal}
export BIASO=${datapath2}/${PREINP}abias 
export BIASO_PC=${datapath2}/${PREINP}abias_pc 
export SATANGO=${datapath2}/${PREINP}satang
export DTFANL=${datapath2}/${PREINP}dtfanl.nc

if [ $cleanup_controlanl == 'true' ]; then
   /bin/rm -f ${SIGANL06}
   /bin/rm -f ${datapath2}/diag*${charnanal2}*nc4
fi

niter=1
alldone='no'
if [ -s $SIGANL06 ]; then
   alldone="yes"
fi 

while [ $alldone == "no" ] && [ $niter -le $nitermax ]; do

export JCAP_A=$JCAP_CTL
export JCAP_B=$JCAP_CTL # high res control background
export HXONLY='NO'
export VERBOSE=YES  
export OMP_NUM_THREADS=$gsi_control_threads
export OMP_STACKSIZE=2048M
export MKL_NUM_THREADS=1
#cores=`python -c "print (${NODES} - 1) * ${corespernode}"`
export nprocs=`expr $cores \/ $OMP_NUM_THREADS`
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`
echo "running with $OMP_NUM_THREADS threads ..."

if [ -z $biascorrdir ]; then # cycled bias correction files
    export GBIAS=${datapathm1}/${PREINPm1}abias
    export GBIAS_PC=${datapathm1}/${PREINPm1}abias_pc
    export GBIASAIR=${datapathm1}/${PREINPm1}abias_air
    export ABIAS=${datapath2}/${PREINP}abias
else # externally specified bias correction files.
    export GBIAS=${biascorrdir}/${analdate}//${PREINP}abias
    export GBIAS_PC=${biascorrdir}/${analdate}//${PREINP}abias_pc
    export GBIASAIR=${biascorrdir}/${analdate}//${PREINP}abias_air
    export ABIAS=${biascorrdir}/${analdate}//${PREINP}abias
fi
export GSATANG=$fixgsi/global_satangbias.txt # not used, but needs to exist

export tmpdir=$datapath2/hybridtmp$$
if [ "$cold_start_bias" == "true" ]; then
    export lread_obs_save=".true."
    export lread_obs_skip=".false."
    echo "${analdate} compute gsi observer to cold start bias correction"
    export HXONLY='YES'
    /bin/rm -rf $tmpdir
    mkdir -p $tmpdir
    sh ${scriptsdir}/${rungsi}
    /bin/rm -rf $tmpdir
    if [  ! -s ${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal2}.nc4 ]; then
       echo "gsi observer step failed"
       echo "no" > ${current_logdir}/run_gsi_anal.log 2>&1
       exit 1
    fi
fi
export lread_obs_save=".false."
export lread_obs_skip=".false."
export HXONLY='NO'
if [ -s $SIGANL06 ] && [ -s ${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal2}.nc4 ]; then
  echo "gsi already completed"
  echo "yes" > ${current_logdir}/run_gsi_anal.log
  exit 0
fi
echo "${analdate} compute gsi analysis increment `date`"
/bin/rm -rf $tmpdir
mkdir -p $tmpdir
/bin/cp -f $datapath2/hybens_info $tmpdir
sh ${scriptsdir}/${rungsi}
status=$?
if [ "$cold_start_bias" == "true" ]; then
  export cold_start_bias=="false"
  export GBIAS=${datapath2}/${PREINP}abias
  export GBIAS_PC=${datapath2}/${PREINP}abias_pc
  export GBIASAIR=${datapath2}/${PREINP}abias_air
  /bin/rm -f ${datapath2}/diag*${charnanal2}*nc4
  echo "${analdate} re-compute gsi analysis increment `date`"
  sh ${scriptsdir}/${rungsi}
  status=$?
fi
if [ $status -ne 0 ]; then
  echo "gsi analysis did not complete sucessfully"
  exitstat=1
else
  if [ ! -s $SIGANL06 ]; then
    echo "gsi analysis did not complete sucessfully"
    exitstat=1
  else
    echo "gsi  completed sucessfully"
    exitstat=0
  fi
fi

if [ $exitstat -eq 0 ]; then
   alldone='yes'
else
   echo "some files missing, try again .."
   niter=$((niter+1))
fi
done

if [ $alldone == 'no' ]; then
    echo "Tried ${nitermax} times and to do gsi analysis and failed"
    echo "no" > ${current_logdir}/run_gsi_anal.log 2>&1
else
    echo "yes" > ${current_logdir}/run_gsi_anal.log 2>&1
    /bin/rm -rf $tmpdir
fi
