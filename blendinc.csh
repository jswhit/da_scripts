#!/bin/csh

setenv VERBOSE YES
setenv OMP_STACKSIZE 256M
pushd ${datapath2}

# compute 3dvar increment.
echo "compute 3dvar increment"
set SIGF=sfg_${analdate}_fhr06_control
set SIGA=sanl_${analdate}_fhr06_control
set SIGO=svarinc_${analdate}_control
set nprocs_save=$nprocs
set mpitaskspernode_save=$mpitaskspernode
set threads_save=$OMP_NUM_THREADS
setenv nprocs 1
setenv mpitaskspernode 1
setenv OMP_NUM_THREADS 1
setenv PGM "${execdir}/makeinc_nemsio.x $SIGA $SIGF $SIGO"
sh ${enkfscripts}/runmpi
if ($status == 0) then
   echo "yes" >! ${current_logdir}/blendinc.log
else
   echo "no" >! ${current_logdir}/blendinc.log
   exit 1
endif

# loop over times in IAU window.
set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`

echo "compute enkf mean increment for ${charfhr}"
set SIGF=sfg_${analdate}_${charfhr}_ensmean
set SIGA=sanl_${analdate}_${charfhr}_ensmean
set SIGO=senkfinc_${analdate}_${charfhr}_ensmean
setenv nprocs 1
setenv mpitaskspernode 1
setenv OMP_NUM_THREADS 1
setenv PGM "${execdir}/makeinc_nemsio.x $SIGA $SIGF $SIGO"
sh ${enkfscripts}/runmpi
if ($status == 0) then
   echo "yes" >! ${current_logdir}/blendinc.log
else
   echo "no" >! ${current_logdir}/blendinc.log
   exit 1
endif

# blend 3dvar and enkf mean increments, update ensemble mean analysis
echo "blend enkf mean and 3dvar increment for ${charfhr}, create new enkf mean analysis"
/bin/mv -f sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr}_ensmean.orig
set filenamein=sfg_${analdate}_${charfhr}_ensmean
set filename_inc1=svarinc_${analdate}_control
set filename_inc2=senkfinc_${analdate}_${charfhr}_ensmean
set filenameout=sanl_${analdate}_${charfhr}_ensmean
setenv nprocs 1
setenv mpitaskspernode 1
setenv OMP_NUM_THREADS 1
setenv PGM "${execdir}/blendinc_nemsio.x $filenamein $filename_inc1 $filename_inc2 $filenameout $alpha $beta"
sh ${enkfscripts}/runmpi

if ($status == 0) then
   echo "yes" >! ${current_logdir}/blendinc.log
else
   echo "no" >! ${current_logdir}/blendinc.log
   exit 1
endif

# blend 3dvar and enkf mean increments, update control analysis
#echo "blend enkf mean and 3dvar increment for ${charfhr}, create new control analysis"
#set filenamein=sfg_${analdate}_${charfhr}_control
#set filename_inc1=svarinc_${analdate}_control
#set filename_inc2=senkfinc_${analdate}_${charfhr}_ensmean
#set filenameout=sanl_${analdate}_${charfhr}_control
#${execdir}/blendinc_nemsio.x $filenamein $filename_inc1 $filename_inc2 $filenameout $alpha $beta 
#if ($status == 0) then
#   echo "yes" >! ${current_logdir}/blendinc.log
#else
#   echo "no" >! ${current_logdir}/blendinc.log
#   exit 1
#endif

echo "recenter ensemble perturbations about new mean for ${charfhr}"
set filename_meanin=sanl_${analdate}_${charfhr}_ensmean.orig
set filename_meanout=sanl_${analdate}_${charfhr}_ensmean
set filenamein=sanl_${analdate}_${charfhr}
set filenameout=sanlr_${analdate}_${charfhr}

setenv nprocs $nprocs_save
setenv mpitaskspernode $mpitaskspernode_save
setenv OMP_NUM_THREADS $threads_save
setenv PGM "${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
set errorcode=0
sh ${enkfscripts}/runmpi
if ($status != 0) set errorcode=1

if ($errorcode == 0) then
   echo "yes" >! ${current_logdir}/blendinc.log
else
   echo "no" >! ${current_logdir}/blendinc.log
   exit 1
endif

# rename files.
set nanal=1
while ($nanal <= $nanals)
   set charnanal_tmp="mem"`printf %03i $nanal`
   set analfiler=sanlr_${analdate}_${charfhr}_${charnanal_tmp}
   set analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
   if ( -s $analfiler) then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      if ($status != 0) set errorcode=1
   else
      echo "no" >! ${current_logdir}/blendinc.log
      exit 1
   endif
   @ nanal = $nanal + 1
end

if ($errorcode == 0) then
   echo "yes" >! ${current_logdir}/blendinc.log
else
   echo "error encountered, copying original files back.."
   echo "no" >! ${current_logdir}/blendinc.log
   # rename files back
   /bin/mv -f sanl_${analdate}_${charfhr}_ensmean.orig sanl_${analdate}_${charfhr}_ensmean
   set nanal=1
   while ($nanal <= $nanals)
      set charnanal_tmp="mem"`printf %03i $nanal`
      set analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
      /bin/mv -f ${analfile}.orig ${analfile}
      @ nanal = $nanal + 1
   end
   exit 1
endif

end # next time
popd

exit 0
