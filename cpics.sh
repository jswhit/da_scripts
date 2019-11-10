# ens members
datapath='/scratch1/NCEPDEV/da/Catherine.Thomas/ICSDIR/L64/2018121600/enkfgdas.20181215/18/'
nanal=81
while [ $nanal -le 80 ]; do
  charnanal="mem`printf %03i $nanal`"
  mkdir -p $charnanal/INPUT
  for filex in ${datapath}/${charnanal}/RESTART/*nc; do
     file=`basename $filex`
     file2=`echo $file | cut -f3-10 -d"."`
     /bin/cp -f $filex ${charnanal}/INPUT/$file2
  done
  nanal=$((nanal+1))
done
# control
datapath='/scratch1/NCEPDEV/da/Catherine.Thomas/ICSDIR/L64/2018121600/gdas.20181215/18'
charnanal="control"
mkdir -p $charnanal/INPUT
for filex in ${datapath}/RESTART/*nc; do
   file=`basename $filex`
   file2=`echo $file | cut -f3-10 -d"."`
   /bin/cp -f $filex ${charnanal}/INPUT/$file2
done
# bias coeffs
datapath='/scratch1/NCEPDEV/da/Catherine.Thomas/ICSDIR/L64/2018121600/gdas.20181216/00'
/bin/cp -f ${datapath}/*bias* .
