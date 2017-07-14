#!/bin/csh

setenv VERBOSE YES
setenv OMP_STACKSIZE 256M
set charnanal="control"

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`

echo "recenter ensemble perturbations about low resolution hybrid analysis"
if ($IAU == ".true.") then
  set filename_meanin=${datapath2}/sanl_${analdate}_${charfhr}_ensmean
  set filename_meanout=${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}
  set filenamein=${datapath2}/sanl_${analdate}_${charfhr}
  set filenameout=${datapath2}/sanlr_${analdate}_${charfhr}
else
  set filename_meanin=${datapath2}/sanl_${analdate}_ensmean
  set filename_meanout=${datapath2}/sanl_${analdate}_${charnanal}
  set filenamein=${datapath2}/sanl_${analdate}
  set filenameout=${datapath2}/sanlr_${analdate}
endif

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
set nanal=1
while ($nanal <= $nanals)
   set charnanal="mem"`printf %03i $nanal`
   if ($IAU == ".true.") then
      set analfiler="${datapath2}/sanlr_${analdate}_${charfhr}_${charnanal}"
      set analfile="${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}"
   else
      set analfiler="${datapath2}/sanlr_${analdate}_${charnanal}"
      set analfile="${datapath2}/sanl_${analdate}_${charnanal}"
   endif
   if ( -s $analfiler) then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      if ($status != 0) set errorcode=1
   endif
   @ nanal = $nanal + 1
end

if ($errorcode == 0) then
   echo "yes" >! ${current_logdir}/recenter_ens.log
else
   echo "no" >! ${current_logdir}/recenter_ens.log
   # rename files back
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
   set nanal=1
   while ($nanal <= $nanals)
      set charnanal="mem"`printf %03i $nanal`
      if ($IAU == ".true.") then
         set analfile="${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}"
      else
         set analfile="${datapath2}/sanl_${analdate}_${charnanal}"
      endif
      /bin/mv -f ${analfile}.orig ${analfile}
      @ nanal = $nanal + 1
   end
   exit 1
endif

end # next time

exit 0
