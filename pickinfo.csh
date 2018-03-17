set date=$1
set infoname=$2
set infos=`ls -1 ${enkfscripts}/global_${infoname}.txt.* | sort -rn`
set date1=$date
foreach info ( $infos )
  set infotest=`basename $info`
  set datex=`echo $infotest | cut -f3 -d"."`
  if ($date >= $datex) then
    set info_use=$info
    break
  endif
end
echo $info_use
