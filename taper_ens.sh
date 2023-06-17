#!/bin/sh

export VERBOSE=YES
export OMP_STACKSIZE=256M
ak_bot=${ak_bot:-"0"}
ak_top=${ak_top:-"0"}
fileprefix=${fileprefix:-"sanl"}
if [ $ak_bot -eq 0 ]; then
   echo "yes" > ${current_logdir}/taper.log
   exit 0
fi
pushd ${datapath2}

analhrs=`echo $enkfstatefhrs | sed 's/,/ /g'`

for nfhr in $analhrs; do
nfhr=$nhr_anal
charfhr="fhr"`printf %02i $nhr_anal`

echo "recenter or blend increments, taper ensemble perturbations"
if [ $hybgain == "false" ]; then
   filename_meanin=${fileprefix}_${analdate}_${charfhr}_control
   alpha_wt=0
else
   filename_meanin=""
   alpha_wt=$alpha
fi
filenamein=${fileprefix}_${analdate}_${charfhr}
filenameout=${fileprefix}r_${analdate}_${charfhr}

cat > taperens.nml << EOF
&setup
  alpha=$alpha_wt,
  beta=$beta,
  ak_bot=500.,
  ak_top=-1.,
  cliptracers=.false.,
  nanals=$nanals,
  filenamein="${filenamein}",
  filenameout="${filenameout}",
  filename_meanin="${filename_meanin}",
  filename_fgmean="sfg_${analdate}_${charfhr}_ensmean",
  filename_3dvar="${fileprefix}_${analdate}_${charfhr}_control",
/
EOF
cat taperens.nml

export PGM="${execdir}/taperens.x"
errorcode=0
if [ -s $filename_meanin ]; then
   ${enkfscripts}/runmpi
   status=$?
   if [ $status -ne 0 ]; then
    errorcode=1
   fi

   if [ $errorcode -eq 0 ]; then
      echo "yes" > ${current_logdir}/taper.log
   else
      echo "no" > ${current_logdir}/taper.log
      exit 1
   fi
   
   # rename files.
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal_tmp="mem"`printf %03i $nanal`
      analfiler=${fileprefix}r_${analdate}_${charfhr}_${charnanal_tmp}
      analfile=${fileprefix}_${analdate}_${charfhr}_${charnanal_tmp}
      if [ -s $analfiler ]; then
         /bin/mv -f $analfile ${analfile}.orig
         /bin/mv -f $analfiler $analfile
         status=$?
         if [ $status -ne 0 ]; then
          errorcode=1
         fi
      else
         echo "no" > ${current_logdir}/taper.log
         exit 1
      fi
      nanal=$((nanal+1))
   done
   
   if [ $errorcode -eq 0 ]; then
      echo "yes" > ${current_logdir}/taper.log
   else
      echo "error encountered, copying original files back.."
      echo "no" > ${current_logdir}/taper.log
      # rename files back
      nanal=1
      while [ $nanal -le $nanals ]; do
         charnanal_tmp="mem"`printf %03i $nanal`
         analfile=${fileprefix}_${analdate}_${charfhr}_${charnanal_tmp}
         /bin/mv -f ${analfile}.orig ${analfile}
         nanal=$((nanal+1))
      done
      exit 1
   fi

   analfiler=${fileprefix}r_${analdate}_${charfhr}_ensmean
   analfile=${fileprefix}_${analdate}_${charfhr}_ensmean
   if [ -s $analfiler ]; then
     /bin/mv -f $analfiler $analfile
   fi
   analfiler=${fileprefix}r_${analdate}_${charfhr}_ensmean.orig
   analfile=${fileprefix}_${analdate}_${charfhr}_ensmean.orig
   if [ -s $analfiler ]; then
     /bin/mv -f $analfiler $analfile
   fi

else
   echo "$filename_meanin missing, skip this time..."
fi

done # next time
   
popd

exit 0
