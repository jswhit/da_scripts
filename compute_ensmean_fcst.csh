#!/bin/csh

if ($machine == 'wcoss') then
   module load nco-gnu-sandybridge
   set nces=`which nes`
else if ($machine == 'gaea') then
   set nces=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/nces
else
   module load nco
   set nces=`which nes`
endif
module list
setenv HOSTFILE ${datapath2}/machinesx

cd ${datapath2}

set fh=${FHMIN}
while ($fh <= $FHMAX)

  set charfhr="fhr`printf %02i $fh`"

  if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean)) then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
      setenv PGM "${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
  endif
  if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean)) then
      /bin/rm -f ${datapath2}/sfg_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} ${JCAP}"
      setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} ${JCAP}"
      sh ${enkfscripts}/runmpi
      if ($fh == $ANALINC) then
      echo "running ${execdir}/getsigensstatp.x ${datapath2}/ sfg_${analdate}_${charfhr} ${nanals}"
      setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sfg_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
      endif
  endif

  @ fh = $fh + $FHOUT

end

# now compute ensemble mean restart files.
if ( $ensmean_restart == 'true' && $fg_only == 'false' ) then
if ( $cleanup_ensmean == 'true' || ( $cleanup_ensmean == 'false' && ! -s ${datapath2}/ensmean/INPUT/fv_core.res.tile1.nc ) ) then
   echo "compute ensemble mean restart files `date`"
   setenv nprocs 1
   setenv mpitaskspernode 1
   setenv OMP_NUM_THREADS $corespernode
   set pathout=${datapath2}/ensmean/INPUT
   mkdir -p $pathout
   set ncount=1
   foreach tile (tile1 tile2 tile3 tile4 tile5 tile6)
      foreach filename (fv_core.res.${tile}.nc fv_tracer.res.${tile}.nc fv_srf_wnd.res.${tile}.nc sfc_data.${tile}.nc)
         setenv PGM "${nces} -O `ls -1 ${datapath2}/mem*/INPUT/${filename}` ${pathout}/${filename}"
         if ($machine == 'theia') then
            set host=`head -$ncount $NODEFILE | tail -1`
            setenv HOSTFILE ${datapath2}/hostfile_nces_${ncount}
            echo $host >! $HOSTFILE
         endif
         echo "computing ens mean for $filename"
         #sh ${enkfscripts}/runmpi &
         $PGM &
         if ($ncount == $NODES) then
            echo "waiting for backgrounded jobs to finish..."
            wait
            set ncount=1
         else
            @ ncount = $ncount + 1
         endif
      end
   end
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   /bin/cp -f ${datapath2}/mem001/INPUT/fv_core.res.nc ${pathout}
   echo "done computing ensemble mean restart files `date`"
endif
endif

if ( $?copy_history_files ) then
   echo "compute ensemble mean history files `date`"
   setenv nprocs 1
   setenv mpitaskspernode 1
   setenv OMP_NUM_THREADS $corespernode
   set pathout=${datapath2}/ensmean
   mkdir -p $pathout
   set ncount=1
   foreach tile (tile1 tile2 tile3 tile4 tile5 tile6)
      foreach filename (fv3_historyp.${tile}.nc)
         setenv PGM "${nces} -4 -L 5 -O `ls -1 ${datapath2}/mem*/${filename}` ${pathout}/${filename}"
         if ($machine == 'theia') then
            set host=`head -$ncount $NODEFILE | tail -1`
            setenv HOSTFILE ${datapath2}/hostfile_nces_${ncount}
            echo $host >! $HOSTFILE
         endif
         echo "computing ens mean for $filename"
         #sh ${enkfscripts}/runmpi &
         $PGM &
         if ($ncount == $NODES) then
            echo "waiting for backgrounded jobs to finish..."
            wait
            set ncount=1
         else
            @ ncount = $ncount + 1
         endif
      end
   end
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   echo "done computing ensemble mean history files `date`"
endif

exit 0
