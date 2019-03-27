# sh submit_job.sh <machine>
# if using SLURM, set env var USE_SLURM
machine=$1
if [ -z $USE_SLURM ]; then
   cat ${machine}_preamble config.sh > job.sh
   if [ $machine == 'wcoss' ]; then
       bsub < job.sh
   elif [ $machine == 'gaea' ]; then
       msub job.sh
   else
       qsub job.sh
   fi
else
   cat ${machine}_preamble_slurm config.sh > job.sh
   sbatch job.sh
fi
