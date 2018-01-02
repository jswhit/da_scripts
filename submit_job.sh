machine=$1
cat ${machine}_preamble config.sh > job.sh
if [ $machine == 'wcoss' ]; then
    bsub < job.sh
elif [ $machine == 'gaea' ]; then
    msub job.sh
elif [ $machine == 'cori' ]; then
    sbatch job.sh
else
    qsub job.sh
fi
