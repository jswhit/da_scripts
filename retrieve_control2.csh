#!/bin/csh
#PBS -A nggps_psd
#PBS -l partition=es,size=1,walltime=10:00:00
#PBS -q rdtn
#PBS -N retrieve_control2
#PBS -e retrieve_control2.err
#PBS -o retrieve_control2.out
module load hsi

set expt=C192C384_hybgain
set hsidir=/ESRL/BMC/gsienkf/2year/whitaker
set date1=2016010606
set date2=2016011518

cd /lustre/f1/${USER}/${expt}

set date=$date1
while ($date <= $date2)
#htar -tvf ${hsidir}/${expt}/${date}_subset.tar
htar -xvf ${hsidir}/${expt}/${date}_subset.tar ${date}/control2
ls -l ${date}/control2/INPUT
set date=`incdate $date 6`
end
