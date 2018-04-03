#!/bin/csh

setenv HOSTFILE ${datapath2}/machinesx

cd ${datapath2}

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."

foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`
set charfhr2=`printf %02i $nhr_anal`

if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sanl_${analdate}_${charfhr}_ensmean)) then
   /bin/rm -f sanl_${analdate}_${charfhr}_ensmean
   setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals}"
   sh ${enkfscripts}/runmpi
   if ($nanals_replay > 0) then
      setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl${nanals_replay}_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals_replay}"
      sh ${enkfscripts}/runmpi
   endif
   if ($nhr_anal == $ANALINC) then
      setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
   endif
endif
# convert sanl files to grib (save for replay)
if ($controlanal != 'true' || $recenter_anal != 'true') then # if true, do in recenter_ens_anal.csh
   setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals} grib"
   sh ${enkfscripts}/runmpi
   if ($nanals_replay > 0) then
      echo "recenter replay ensemble perturbations about low resolution hybrid analysis"
      set filename_meanin=sanl${nanals_replay}_${analdate}_${charfhr}_ensmean
      set filename_meanout=sanl_${analdate}_${charfhr}_ensmean
      set filenamein=sanl_${analdate}_${charfhr}
      set filenameout=sanl${nanals_replay}_${analdate}_${charfhr}
      setenv PGM "${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals_replay"
      sh ${enkfscripts}/runmpi
      # convert sanl files to grib after recentering (save for replay)
      setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl${nanals_replay}_${analdate}_${charfhr} ${nanals_replay} grib"
      sh ${enkfscripts}/runmpi
   endif
endif

end
ls -l ${datapath2}/sanl_${analdate}*ensmean

exit 0
