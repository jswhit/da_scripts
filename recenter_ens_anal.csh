#!/bin/csh

setenv VERBOSE YES
setenv OMP_STACKSIZE 256M
set charnanal="control"
pushd ${datapath2}

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`

echo "recenter ensemble perturbations about low resolution hybrid analysis"
set filename_meanin=sanl_${analdate}_${charfhr}_ensmean
set filename_meanout=sanl_${analdate}_${charfhr}_${charnanal}
set filenamein=sanl_${analdate}_${charfhr}
set filenameout=sanlr_${analdate}_${charfhr}

setenv PGM "${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
set errorcode=0
sh ${enkfscripts}/runmpi
if ($status != 0) set errorcode=1

if ($errorcode == 0) then
   echo "yes" >! ${current_logdir}/recenter_ens.log
else
   echo "no" >! ${current_logdir}/recenter_ens.log
   exit 1
endif

# rename files.
/bin/mv -f $filename_meanin  ${filename_meanin}.orig
/bin/cp -f $filename_meanout $filename_meanin
/bin/mv -f $filename_meanin.grib  ${filename_meanin}.grib.orig
/bin/cp -f $filename_meanout.grib $filename_meanin.grib
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
      echo "no" >! ${current_logdir}/recenter_ens.log
      exit 1
   endif
   @ nanal = $nanal + 1
end

if ($errorcode == 0) then
   echo "yes" >! ${current_logdir}/recenter_ens.log
else
   echo "error encountered, copying original files back.."
   echo "no" >! ${current_logdir}/recenter_ens.log
   # rename files back
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
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
