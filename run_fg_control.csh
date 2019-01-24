# run high-res control first guess.
# first, clean up old first guesses.

if ($replay_controlfcst == 'true') then
   setenv charnanal "control2"
else
   setenv charnanal "control"
endif
echo "charnanal = $charnanal"
setenv DATOUT "${datapath}/${analdatep1}"
echo "DATOUT = $DATOUT"
mkdir -p ${DATOUT}

setenv OMP_NUM_THREADS $control_threads
setenv OMP_STACKSIZE 2048m
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"
setenv nprocs `expr $control_proc \/ $OMP_NUM_THREADS`
echo "nprocs = $nprocs"
setenv mpitaskspernode `expr $corespernode \/ $OMP_NUM_THREADS`
echo "mpitaskspernode = $mpitaskspernode"
if ($machine == 'theia') then
   if ($OMP_NUM_THREADS == 1) then
      setenv HOSTFILE $PBS_NODEFILE
   else
      setenv HOSTFILE ${datapath2}/hostfile_control
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} >&! $HOSTFILE
   endif
   echo "HOSTFILE = $HOSTFILE"
endif

setenv RES $RES_CTL
echo "RES = $RES"
setenv write_groups "$write_groups_ctl"
echo "write_groups = $write_groups"
setenv layout "$layout_ctl"
echo "layout = $layout"
setenv dt_atmos $dt_atmos_ctl
echo "dt_atmos = $dt_atmos"
setenv fv_sg_adj $fv_sg_adj_ctl
echo "fv_sg_adj = $fv_sg_adj"
setenv cdmbgwd "$cdmbgwd_ctl"
echo "cdmbgwd = $cdmbgwd"
if ($?psautco_ctl) then
setenv psautco "$psautco_ctl"
echo "psautco = $psautco"
endif
if ($?prautco_ctl) then
setenv prautco "$psautco_ctl"
echo "prautco = $psautco"
endif
if ($?k_split_ctl) then
setenv k_split "${k_split_ctl}"
endif
if ($?n_split_ctl) then
setenv n_split "${n_split_ctl}"
endif
setenv fg_proc $nprocs
echo "fg_proc = $fg_proc"

# turn off stochastic physics
setenv SKEB 0
setenv SPPT 0
setenv SHUM 0
echo "SKEB SPPT SHUM = $SKEB $SPPT $SHUM"

if ($cleanup_fg == 'true') then
   echo "deleting existing files..."
   /bin/rm -f ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc
   /bin/rm -f ${DATOUT}/sfg_${analdatep1}*${charnanal}
   /bin/rm -f ${DATOUT}/bfg_${analdatep1}*${charnanal} 
endif

setenv niter 1
set outfiles=""
set fhr=$FHMIN
while ($fhr <= $FHMAX)
   set charhr="fhr`printf %02i $fhr`"
   set outfiles = "${outfiles} ${datapath}/${analdatep1}/sfg_${analdatep1}_${charhr}_${charnanal} ${datapath}/${analdatep1}/bfg_${analdatep1}_${charhr}_${charnanal}"
   @ fhr = $fhr + $FHOUT
end
set alldone='yes'
foreach outfile ($outfiles) 
  if ( ! -s $outfile) then
    echo "${outfile} is missing"
    set alldone='no'
  else
    echo "${outfile} is OK"
  endif
end
echo "${analdate} compute first guesses `date`"
while ($alldone == 'no' && $niter <= $nitermax)
    if ($niter == 1) then
       sh ${enkfscripts}/${rungfs}
       set exitstat=$status
    else
       sh ${enkfscripts}/${rungfs}
       set exitstat=$status
    endif
    if ($exitstat == 0) then
       set alldone='yes'
       foreach outfile ($outfiles) 
         if ( ! -s $outfile) then
           echo "${outfile} is missing"
           set alldone='no'
         else
           echo "${outfile} is OK"
         endif
       end
    else
       set alldone='no'
       echo "some files missing, try again .."
       @ niter = $niter + 1
       setenv niter $niter
    endif
end

if ( ! -s ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc && $controlfcst == 'true' && $?copy_history_files) then
   # interpolate to 1x1 grid
   cd ${enkfscripts}
   echo "interpolate pressure level history files from ${charnanal} forecast to 1x1 deg grid`date`"
   $python ncinterp.py ${datapathp1}/${charnanal} ${datapath2}/fv3${charnanal}_historyp_${analdate}_latlon.nc $RES_CTL $analdate
endif
echo "all done `date`"

if($alldone == 'no') then
    echo "Tried ${nitermax} times to run high-res control first-guess and failed: ${analdate}"
    echo "no" >&! ${current_logdir}/run_fg_control.log
    exit 1
else
    echo "yes" >&! ${current_logdir}/run_fg_control.log
    exit 0
endif
