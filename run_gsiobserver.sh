#!/bin/sh
# do hybrid observer.

if [ -z $charnanal2 ]; then
  export charnanal2=$charnanal
fi

# run observer on full res control forecast grid
export LONA=$LONB_CTL
export LATA=$LATB_CTL
export JCAP=$JCAP_CTL
##export CLEAN="NO"
export NLAT=$((${LATA}+2))

# charanal is an env var set in parent script
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
echo "NOCONV:" $NOCONV
diagfile=${datapath2}/diag_conv_uv_ges.${analdate}_${charnanal2}.nc4

if [ $cleanup_observer == 'true' ]; then
  echo "removing diag files"
  /bin/rm -rf ${datapath2}/diag*nc4
fi
ls -l $diagfile

niter=1
alldone='no'
if [ -s ${diagfile} ]; then
  alldone='yes'
fi

while [ $alldone == "no" ] && [ $niter -le $nitermax ]; do

export JCAP_A=$JCAP
export JCAP_B=$JCAP_CTL
export VERBOSE=YES  
export OMP_NUM_THREADS=$gsi_control_threads
export OMP_STACKSIZE=2048M
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

export lread_obs_save=".false."
export lread_obs_skip=".false."
export HXONLY='YES'
if [ -s ${diagfile} ]; then
  echo "gsi hybrid observer already completed"
  echo "yes" > ${current_logdir}/run_gsi_observer.log 2>&1
  exit 0
fi
echo "${analdate} compute gsi hybrid observer `date`"
export tmpdir=$datapath2/gsitmp_${charnanal2}
/bin/rm -rf $tmpdir
mkdir -p $tmpdir
/bin/cp -f $datapath2/hybens_info $tmpdir
sh ${scriptsdir}/${rungsi}
status=$?

if [ $status -ne 0 ]; then
  echo "gsi hybrid observer did not complete sucessfully"
  exitstat=1
else
  if [ ! -s ${diagfile} ]; then
    ls -l ${diagfile}
    echo "gsi hybrid observer did not complete sucessfully"
    exitstat=1
  else
    echo "gsi hybrid completed sucessfully"
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
    echo "Tried ${nitermax} times and to do gsi hybrid observer and failed"
    echo "no" > ${current_logdir}/run_gsi_observer.log 2>&1
else
    echo "yes" > ${current_logdir}/run_gsi_observer.log 2>&1
    /bin/rm -rf $tmpdir
fi
