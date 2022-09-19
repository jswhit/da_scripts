export exptname="C192_hybcov_6hourly_iau_p8"
export datapath=/scratch2/BMC/gsienkf/whitaker/${exptname}
export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
export save_hpss_full="false"
export save_hpss_subset="true"
export machine="hera"
date=2021090106
while [ $date -le 2021100100 ]; do
 export analdate=$date
 export datapath2=${datapath}/${analdate}
 date=`incdate $date 6`
 sbatch job_hpss.sh
done
