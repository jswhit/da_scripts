for diagfile in  ../../C192_hybcov_hourly_esmda2/2021082923/diag*ensmean*nc4; do
   echo $diagfile
   python checkobtime.py $diagfile
done
