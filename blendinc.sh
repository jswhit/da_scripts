#!/bin/sh

export VERBOSE=YES
export OMP_STACKSIZE=256M
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"

for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`
echo "recenter ensemble perturbations about new mean for ${charfhr}"

/bin/mv -f sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr}_ensmean.orig
filename_fg=sfg_${analdate}_${charfhr}_ensmean # ens mean first guess
if [[ $HRLY_DA == "YES" ]]; then
   filename_anal1=sanl_${analdate}_fhr04_control # 3dvar analysis
elif [[ $HRLY_DA == "NO" ]]; then
   filename_anal1=sanl_${analdate}_fhr06_control # 3dvar analysis
fi
filename_anal2=sanl_${analdate}_${charfhr}_ensmean.orig # EnKF analysis
filename_anal=sanl_${analdate}_${charfhr}_ensmean # analysis from blended increments
filenamein=sanl_${analdate}_${charfhr}
filenameout=sanlr_${analdate}_${charfhr}
# new_anal (filename_anal) = fg + alpha*(anal_3dvar-fg) + beta*(anal_enkf-fg)
#                          = (1.-alpha-beta)*fg + alpha*anal_3dvar + beta*anal_enkf
export PGM="${execdir}/recenterncio_hybgain.x $filename_fg $filename_anal1 $filename_anal2 $filename_anal $filenamein $filenameout $alpha $beta $nanals"
errorcode=0
${enkfscripts}/runmpi
status=$?
if [ $status -ne 0 ]; then
  errorcode=1
fi

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/blendinc.log
else
   echo "no" > ${current_logdir}/blendinc.log
   exit 1
fi

# rename files.
nanal=1
while [ $nanal -le $nanals ]; do
   charnanal_tmp="mem"`printf %03i $nanal`
   analfiler=sanlr_${analdate}_${charfhr}_${charnanal_tmp}
   analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
   if [ -s $analfiler ]; then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      status=$?
      if [ $status -ne 0 ]; then
        errorcode=1
      fi
   else
      echo "no" > ${current_logdir}/blendinc.log
      exit 1
   fi
   nanal=$((nanal+1))
done

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/blendinc.log
else
   echo "error encountered, copying original files back.."
   echo "no" > ${current_logdir}/blendinc.log
   # rename files back
   /bin/mv -f sanl_${analdate}_${charfhr}_ensmean.orig sanl_${analdate}_${charfhr}_ensmean
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal_tmp="mem"`printf %03i $nanal`
      analfile=sanl_${analdate}_${charfhr}_${charnanal_tmp}
      /bin/mv -f ${analfile}.orig ${analfile}
      nanal=$((nanal+1))
   done
   exit 1
fi

done # next time
echo "all done `date`"
popd

exit 0
