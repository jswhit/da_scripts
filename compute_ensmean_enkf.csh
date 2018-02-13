#!/bin/csh

#setenv HOSTFILE $datapath2/machinesx # set in main.csh

cd ${datapath2}

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."

foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`
set charfhr2=`printf %02i $nhr_anal`

if ($iau_delthrs != -1) then
   if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sanl_${analdate}_${charfhr}_ensmean)) then
   /bin/rm -f sanl_${analdate}_${charfhr}_ensmean
   setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals}"
   sh ${enkfscripts}/runmpi
   if ($nhr_anal == $ANALINC) then
      setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
   endif
   endif
# convert sanl files to grib (save for replay)
   if ($controlanal != 'true' || $recenter_anal != 'true') then # if true, do in recenter_ens_anal.csh
      setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals} grib"
      sh ${enkfscripts}/runmpi
   endif

else
   if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sanl_${analdate}_ensmean)) then
   /bin/rm -f sanl_${analdate}_ensmean
   setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_ensmean sanl_${analdate} ${nanals}"
   sh ${enkfscripts}/runmpi
   setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sanl_${analdate} ${nanals}"
   sh ${enkfscripts}/runmpi
   if ($controlanal != 'true' || $recenter_anal != 'true') then # if true, do in recenter_ens_anal.csh
      setenv PGM "${execdir}/cnvnemsp.x ${datapath2}/ sanl_${analdate} ${nanals} grib"
      sh ${enkfscripts}/runmpi
   endif
   endif
endif

end
ls -l ${datapath2}/sanl_${analdate}*ensmean

exit 0
