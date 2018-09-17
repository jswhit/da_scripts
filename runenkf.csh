#!/bin/csh 

# need symlinks for satbias_angle, satbias_in, satinfo
if ( ! $?biascorrdir ) then # cycled bias correction files
    if ($hybgain == "true") then
       # use bias correction files updated by 3DVar (3DVar run before EnKF).
       setenv GBIAS ${datapath2}/${PREINP}abias
       setenv GBIAS_PC ${datapath2}/${PREINP}abias_pc
       setenv GBIASAIR ${datapath2}/${PREINP}abias_air
    else 
       setenv GBIAS ${datapathm1}/${PREINPm1}abias
       setenv GBIAS_PC ${datapathm1}/${PREINPm1}abias_pc
       setenv GBIASAIR ${datapathm1}/${PREINPm1}abias_air
    endif
    if ($cold_start_bias == "true") then
      setenv GBIAS ${datapath2}/${PREINP}abias
      setenv GBIAS_PC ${datapath2}/${PREINP}abias_pc
      setenv GBIASAIR ${datapath2}/${PREINP}abias_air
    endif
    setenv ABIAS ${datapath2}/${PREINP}abias
else # externally specified bias correction files.
    setenv GBIAS ${biascorrdir}/${analdate}//${PREINP}abias
    setenv GBIAS_PC ${biascorrdir}/${analdate}//${PREINP}abias_pc
    setenv GBIASAIR ${biascorrdir}/${analdate}//${PREINP}abias_air
    setenv ABIAS ${biascorrdir}/${analdate}//${PREINP}abias
endif
setenv GSATANG $fixgsi/global_satangbias.txt # not used, but needs to exist

ln -fs $GBIAS   ${datapath2}/satbias_in
ln -fs $GBIAS_PC   ${datapath2}/satbias_pc
ln -fs $GSATANG ${datapath2}/satbias_angle
#ln -fs ${gsipath}/fix/global_satinfo.txt ${datapath2}/satinfo
ln -fs ${SATINFO} ${datapath2}/satinfo
ls -l ${datapath2}/satinfo
#ln -fs ${gsipath}/fix/global_convinfo.txt ${datapath2}/convinfo
ln -fs ${CONVINFO} ${datapath2}/convinfo
ln -fs ${ANAVINFO_ENKF} ${datapath2}/anavinfo
ls -l ${datapath2}/convinfo
ln -fs ${gsipath}/fix/global_ozinfo.txt ${datapath2}/ozinfo
ln -fs ${gsipath}/fix/global_scaninfo.txt ${datapath2}/scaninfo
ln -fs ${current_logdir}/satinfo.out ${datapath2}/fort.207
ln -fs ${current_logdir}/ozinfo.out ${datapath2}/fort.206
ln -fs ${current_logdir}/convinfo.out ${datapath2}/fort.205

# remove previous analyses
if ($cleanup_anal == 'true') then
   /bin/rm -f ${datapath2}/sanl_*mem*
endif

set niter=1
set alldone='no'
echo "${analdate} compute enkf analysis increment `date`"
while ($alldone == 'no' && $niter <= $nitermax)
    echo "${enkfscripts}/${ensda}"
    csh ${enkfscripts}/${ensda} 
    set exitstat=$status
    if ($exitstat == 0) then
       set alldone='yes'
    else
       echo "some files missing, try again .."
       @ niter = $niter + 1
    endif
end
if($alldone == 'no') then
    echo "Tried ${nitermax} times to run ensda and failed: ${analdate}"
    echo "no" >&! ${current_logdir}/run_enkf.log
else
    echo "yes" >&! ${current_logdir}/run_enkf.log
endif
echo "${analdate} done computing enkf analysis increment `date`"
exit 0
