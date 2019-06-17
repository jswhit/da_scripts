date=$1
infoname=$2
infos=`ls -1 ${enkfscripts}/global_${infoname}.txt.* | sort -rn`
date1=$date
for info in $infos; do
  infotest=`basename $info`
  datex=`echo $infotest | cut -f3 -d"."`
  if  [ $date -ge $datex ]; then
    info_use=$info
    break
  fi
done
echo $info_use
