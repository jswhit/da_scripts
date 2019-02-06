#!/bin/csh

setenv VERBOSE YES
setenv OMP_STACKSIZE 256M
pushd ${datapath2}

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"

foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`
echo "recenter ensemble perturbations about new mean for ${charfhr}"

/bin/mv -f sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr}_ensmean.orig
set filename_fg=sfg_${analdate}_${charfhr}_ensmean # ens mean first guess
set filename_anal1=sanl_${analdate}_fhr06_control # 3dvar analysis
set filename_anal2=sanl_${analdate}_${charfhr}_ensmean.orig # EnKF analysis
set filename_anal=sanl_${analdate}_${charfhr}_ensmean # analysis from blended increments
set filenamein=sanl_${analdate}_${charfhr}
set filenameout=sanlr_${analdate}_${charfhr}
# new_anal (filename_anal) = fg + alpha*(anal_3dvar-fg) + beta*(anal_enkf-fg)
#                          = (1.-alpha-beta)*fg + alpha*anal_3dvar + beta*anal_enkf
setenv PGM "${execdir}/recenternemsiop_hybgain.x $filename_fg $filename_anal1 $filename_anal2 $filename_anal $filenamein $filenameout $alpha $beta $nanals"
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
echo "all done `date`"
popd

exit 0
