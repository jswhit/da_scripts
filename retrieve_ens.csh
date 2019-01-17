#!/bin/csh
#PBS -A nggps_psd
#PBS -l partition=es,size=1,walltime=10:00:00
#PBS -q rdtn
#PBS -N retrieve_ens
#PBS -e retrieve_ens.err
#PBS -o retrieve_ens.out
module load hsi

set expt=C192C384_hybgain
set hsidir=/ESRL/BMC/gsienkf/2year/whitaker
set date=2016010506
set datem1=2016010500
cd /lustre/f1/${USER}/${expt}

set hr=`echo $datem1 | cut -c9-10`
htar -xvf ${hsidir}/${expt}/${datem1}_subset.tar ${datem1}/gdas1.t${hr}z.abias ${datem1}/gdas1.t${hr}z.abias_pc ${datem1}/gdas1.t${hr}z.abias_air
htar -xvf ${hsidir}/${expt}/${date}_subset.tar
cd ${date} 
htar -xvf ${hsidir}/${expt}/${date}_fgens.tar
htar -xvf ${hsidir}/${expt}/${date}_fgens2.tar
