#!/bin/csh

set python=`which python`
set nces=`which nces`
if ($machine == 'wcoss') then
   module load nco-gnu-sandybridge
else if ($machine == 'gaea') then
   set nces=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/nces
   set python=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/bin/python
else if ($machine == 'theia') then
   set python=/contrib/anaconda/2.3.0/bin/python
   module load nco
else
   module load nco
endif
module list
setenv HOSTFILE ${datapath2}/machinesx

cd ${datapath2}

#set fh=${FHMIN}
set fh=0
while ($fh <= $FHMAX)

  set charfhr="fhr`printf %02i $fh`"

  # convert control forecasts to grib
  # (do this in adjustps.sh instead)
  #setenv nprocs_save $nprocs
  #setenv mpitaskspernode_save $mpitaskspernode
  #setenv nprocs 1
  #setenv mpitaskspernode 1
  #if ($replay_controlfcst == 'true') then
  #if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_control2.grib)) then
  #setenv PGM "${execdir}/cnvnems.x ${datapath2}/sfg_${analdate}_${charfhr}_control2 ${datapath2}/sfg_${analdate}_${charfhr}_control2.grib grib"
  #sh ${enkfscripts}/runmpi
  #endif
  #else
  #if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_control.grib)) then
  #setenv PGM "${execdir}/cnvnems.x ${datapath2}/sfg_${analdate}_${charfhr}_control ${datapath2}/sfg_${analdate}_${charfhr}_control.grib grib"
  #sh ${enkfscripts}/runmpi
  #endif
  #endif
  #setenv nprocs $nprocs_save
  #setenv mpitaskspernode $mpitaskspernode_save

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

# now compute ensemble mean restart files (only at 00UTC).
if ( $ensmean_restart == 'true' && $fg_only == 'false' && $hr == '06') then
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

if ( $cleanup_ensmean == 'true' && $?copy_history_files ) then
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
   # interpolate to 1x1 grid
   cd ${enkfscripts}
   # dont wait for this to finish
   $python ncinterp.py ${datapath2}/ensmean fv3_historyp_latlon.nc $RES $analdatem1 &
endif


exit 0
