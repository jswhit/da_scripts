#!/bin/sh

export VERBOSE=YES
export OMP_STACKSIZE=256M
charnanal="control"
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`

# control analysis is at higher resolution, change resolution and adjust topography
if [ $controlfcst == "true" ] && [ $replay_controlfcst == 'false' ] && [ $LONB -ne $LONB_CTL ]; then
    sh ${enkfscripts}/chgres.sh $datapath2/sanl_${analdate}_${charfhr}_${charnanal} $datapath2/sanl_${analdate}_${charfhr}_ensmean $datapath2/sanl_${analdate}_${charfhr}_${charnanal}.chgres 
    if [ $? -ne 0 ]; then
       echo "chgres failed, exiting.."
       echo "no" > ${current_logdir}/recenter_ens.log
       exit 1
    fi
fi

echo "recenter ensemble perturbations about low resolution hybrid analysis"
filename_meanin=sanl_${analdate}_${charfhr}_ensmean
if [ $controlfcst == "true" ] && [ $replay_controlfcst == 'false' ] && [ $LONB -ne $LONB_CTL ]; then
   filename_meanout=sanl_${analdate}_${charfhr}_${charnanal}.chgres
else
   filename_meanout=sanl_${analdate}_${charfhr}_${charnanal}
fi
filenamein=sanl_${analdate}_${charfhr}
filenameout=sanlr_${analdate}_${charfhr}

export PGM="${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
errorcode=0
${enkfscripts}/runmpi
status=$?
if [ $status -ne 0 ]; then
 errorcode=1
fi

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/recenter_ens.log
else
   echo "no" > ${current_logdir}/recenter_ens.log
   exit 1
fi

# rename files.
/bin/mv -f $filename_meanin  ${filename_meanin}.orig
/bin/cp -f $filename_meanout $filename_meanin
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
      echo "no" > ${current_logdir}/recenter_ens.log
      exit 1
   fi
   nanal=$((nanal+1))
done

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/recenter_ens.log
else
   echo "error encountered, copying original files back.."
   echo "no" >! ${current_logdir}/recenter_ens.log
   # rename files back
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
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
popd

exit 0
