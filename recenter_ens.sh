#!/bin/sh

export VERBOSE=YES
export OMP_STACKSIZE=256M
charnanal=${charnanal:-"varanal"}
recenter_ensmean_wgt=${recenter_ensmean_wgt:-"0"}
recenter_control_wgt=${recenter_control_wgt:-"100"}
fileprefix=${fileprefix:-"sanl"}
pushd ${datapath2}

fh=${FHMIN}
while [ $fh -le $FHMAX ]; do
   charfhr="fhr"`printf %02i $fh`
   
   echo "recenter ensemble perturbations"
   filename_meanin=${fileprefix}_${analdate}_${charfhr}_ensmean
   filename_meanout=${fileprefix}_${analdate}_${charfhr}_${charnanal}
   filenamein=${fileprefix}_${analdate}_${charfhr}
   filenameout=${fileprefix}r_${analdate}_${charfhr}
   
   export PGM="${execdir}/recenterens_ncio.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals $recenter_ensmean_wgt $recenter_control_wgt"
   errorcode=0
   if [ -s $filename_meanin ]; then
      ${enkfscripts}/runmpi
      status=$?
      if [ $status -ne 0 ]; then
       errorcode=1
      fi
   
      if [ $errorcode -eq 0 ]; then
         echo "yes" > ${current_logdir}/recenter.log
      else
         echo "no" > ${current_logdir}/recenter.log
         exit 1
      fi
      
      # rename files.
      /bin/mv -f $filename_meanin  ${filename_meanin}.orig
      /bin/cp -f $filename_meanout $filename_meanin
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
            echo "no" > ${current_logdir}/recenter.log
            exit 1
         fi
         nanal=$((nanal+1))
      done
      
      if [ $errorcode -eq 0 ]; then
         echo "yes" > ${current_logdir}/recenter.log
      else
         echo "error encountered, copying original files back.."
         echo "no" >! ${current_logdir}/recenter.log
         # rename files back
         /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
         nanal=1
         while [ $nanal -le $nanals ]; do
            charnanal_tmp="mem"`printf %03i $nanal`
            analfile=${fileprefix}_${analdate}_${charfhr}_${charnanal_tmp}
            /bin/mv -f ${analfile}.orig ${analfile}
            nanal=$((nanal+1))
         done
         exit 1
      fi

   else
      echo "$filename_meanin missing, skip this time..."
   fi
   
   fh=$((fh+FHOUT))
done # next time
popd

exit 0
