datapath="/scratch2/BMC/gsienkf/Jeffrey.S.Whitaker/$1"
date=$2
nanals=80
while [ $date -le $3 ]; do
nmem=1
pstend_ensmean=0
while [ $nmem -le $nanals ]; do
charmem=mem`printf %03i $nmem`
pstend=`grep ' mean abs pgr change' ${datapath}/${date}/logs/run_fg_${charmem}.iter1.out | grep 'hour     1.000' | awk '{print $10 }'`
pstend_ensmean=`python -c "print(${pstend_ensmean}+${pstend}/${nanals}.)"`
nmem=$[$nmem+1]
done
echo "$date $pstend_ensmean"
date=`incdate $date 1`
done
