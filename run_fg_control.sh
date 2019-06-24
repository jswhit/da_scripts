# run high-res control first guess.
# first, clean up old first guesses.

if [ $replay_controlfcst == 'true' ]; then
   export charnanal="control2"
else
   export charnanal="control"
fi
echo "charnanal = $charnanal"
export DATOUT="${datapath}/${analdatep1}"
echo "DATOUT = $DATOUT"
mkdir -p ${DATOUT}

export OMP_NUM_THREADS=$control_threads
export OMP_STACKSIZE=2048m
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"
export nprocs=`expr $control_proc \/ $OMP_NUM_THREADS`
echo "nprocs = $nprocs"
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`
echo "mpitaskspernode = $mpitaskspernode"
if [ -z $SLURM_JOB_ID ] && [ $machine == 'theia' ]; then
   if [ $OMP_NUM_THREADS -gt 1 ]; then
      export HOSTFILE=$PBS_NODEFILE
   else
      export HOSTFILE=${datapath2}/hostfile_control
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} > $HOSTFILE
   fi
   echo "HOSTFILE = $HOSTFILE"
fi

export RES=$RES_CTL
echo "RES = $RES"
export write_groups="$write_groups_ctl"
echo "write_groups = $write_groups"
export layout="$layout_ctl"
echo "layout = $layout"
export dt_atmos=$dt_atmos_ctl
echo "dt_atmos = $dt_atmos"
export fv_sg_adj=$fv_sg_adj_ctl
echo "fv_sg_adj = $fv_sg_adj"
export cdmbgwd="$cdmbgwd_ctl"
echo "cdmbgwd = $cdmbgwd"
if [ ! -z $psautco_ctl ]; then
export psautco="$psautco_ctl"
echo "psautco = $psautco"
fi
if [ ! -z $prautco_ctl ]; then
export prautco="$psautco_ctl"
echo "prautco = $psautco"
fi
if [ ! -z $k_split_ctl ]; then
export k_split="${k_split_ctl}"
fi
if [ ! -z $n_split_ctl ]; then
export n_split="${n_split_ctl}"
fi
export fg_proc=$nprocs
echo "fg_proc = $fg_proc"

# turn off stochastic physics
export SKEB=0
export SPPT=0
export SHUM=0
echo "SKEB SPPT SHUM = $SKEB $SPPT $SHUM"

if [ $cleanup_fg == 'true' ]; then
   echo "deleting existing files..."
   /bin/rm -f ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc
   /bin/rm -f ${DATOUT}/sfg_${analdatep1}*${charnanal}
   /bin/rm -f ${DATOUT}/bfg_${analdatep1}*${charnanal} 
fi

export niter=1
outfiles=""
fhr=$FHMIN
while  [ $fhr -le $FHMAX ]; do
   charhr="fhr`printf %02i $fhr`"
   outfiles="${outfiles} ${datapath}/${analdatep1}/sfg_${analdatep1}_${charhr}_${charnanal} ${datapath}/${analdatep1}/bfg_${analdatep1}_${charhr}_${charnanal}"
   fhr=$((fhr+FHOUT))
done
alldone='yes'
for outfile in $outfiles; do
  if [ ! -s $outfile ]; then
    echo "${outfile} is missing"
    alldone='no'
  else
    echo "${outfile} is OK"
  fi
done
echo "${analdate} compute first guesses `date`"
while [ $alldone == 'no' ] && [ $niter -le $nitermax ]; do
    if [ $niter -eq 1 ]; then
       sh ${enkfscripts}/${rungfs}
       exitstat=$?
    else
       sh ${enkfscripts}/${rungfs}
       exitstat=$?
    fi
    if [ $exitstat -eq 0 ]; then
       alldone='yes'
       for outfile in $outfiles; do
         if [ ! -s $outfile ]; then
           echo "${outfile} is missing"
           alldone='no'
         else
           echo "${outfile} is OK"
         fi
       done
    else
       alldone='no'
       echo "some files missing, try again .."
       niter=$((niter+1))
       export niter=$niter
    fi
done

if [ ! -s ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc ] && [ $controlfcst == 'true' ] && [ -z $copy_history_files ]; then
   # interpolate to 1x1 grid
   cd ${enkfscripts}
   echo "interpolate pressure level history files from ${charnanal} forecast to 1x1 deg grid `date`"
   $python ncinterp.py ${datapathp1}/${charnanal} ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc $RES_CTL $analdate
fi
echo "all done `date`"

if [ $alldone == 'no' ]; then
    echo "Tried ${nitermax} times to run high-res control first-guess and failed: ${analdate}"
    echo "no" > ${current_logdir}/run_fg_control.log 2>&1
else
    echo "yes" > ${current_logdir}/run_fg_control.log 2>&1
fi
