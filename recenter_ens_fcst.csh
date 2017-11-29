#!/bin/csh

setenv VERBOSE YES
setenv OMP_STACKSIZE 256M
set charnanal="control"
pushd ${datapath2}

set fh=$FHMIN
while ($fh <= $FHMAX) 
set charfhr="fhr`printf %02i $fh`"

echo "recenter ensemble perturbations about control forecast"
set filename_meanin=sfg_${analdate}_${charfhr}_ensmean
set filename_meanout=sfg_${analdate}_${charfhr}_${charnanal}
set filenamein=sfg_${analdate}_${charfhr}
set filenameout=sfgr_${analdate}_${charfhr}

setenv PGM "${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
set errorcode=0
sh ${enkfscripts}/runmpi
if ($status != 0) set errorcode=1

if ($errorcode != 0) then
   echo "no" >! ${current_logdir}/recenter_ens.log
   exit 1
endif

# rename files.
/bin/mv -f $filename_meanin  ${filename_meanin}.orig
/bin/cp -f $filename_meanout $filename_meanin
set nanal=1
while ($nanal <= $nanals)
   set charnanal_ens="mem"`printf %03i $nanal`
   set fgfiler=sfgr_${analdate}_${charfhr}_${charnanal_ens}
   set fgfile=sfg_${analdate}_${charfhr}_${charnanal_ens}
   if ( -s $fgfiler) then
      /bin/mv -f $fgfile ${fgfile}.orig
      /bin/mv -f $fgfiler $fgfile
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
      set charnanal_ens="mem"`printf %03i $nanal`
      set fgfile=sfg_${analdate}_${charfhr}_${charnanal_ens}
      /bin/mv -f ${fgfile}.orig ${fgfile}
      @ nanal = $nanal + 1
   end
   exit 1
endif

@ fh = $fh + $FHOUT
end # next time
popd

echo "yes" >! ${current_logdir}/recenter_ens.log

exit 0
