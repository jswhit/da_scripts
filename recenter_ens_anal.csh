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
if ($iau_delthrs != -1) then
  set filename_meanin=sanl_${analdate}_${charfhr}_ensmean
  set filename_meanout=sanl_${analdate}_${charfhr}_${charnanal}
  set filenamein=sanl_${analdate}_${charfhr}
  set filenameout=sanlr_${analdate}_${charfhr}
else
  set filename_meanin=sanl_${analdate}_ensmean
  set filename_meanout=sanl_${analdate}_${charnanal}
  set filenamein=sanl_${analdate}
  set filenameout=sanlr_${analdate}
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
   set charnanal_tmp="mem"`printf %03i $nanal`
   if ($iau_delthrs != -1) then
      set analfiler=sanlr_${analdate}_${charfhr}_${charnanal_tmp}
      set analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
   else
      set analfiler=sanlr_${analdate}_${charnanal_tmp}
      set analfile=sanl_${analdate}_${charnanal_tmp}
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
   echo "error encountered, copying original files back.."
   echo "no" >! ${current_logdir}/recenter_ens.log
   # rename files back
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
   set nanal=1
   while ($nanal <= $nanals)
      set charnanal_tmp="mem"`printf %03i $nanal`
      if ($iau_delthrs != -1) then
         set analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
      else
         set analfile=sanl_${analdate}_${charnanal_tmp}
      endif
      /bin/mv -f ${analfile}.orig ${analfile}
      @ nanal = $nanal + 1
   end
   exit 1
endif

# convert sanl files to grib after recentering (save for replay)
if ($iau_delthrs != -1) then
   setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals} grib"
   sh ${enkfscripts}/runmpi
else
   setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl_${analdate} ${nanals} grib"
   sh ${enkfscripts}/runmpi
endif

end # next time
popd

exit 0
