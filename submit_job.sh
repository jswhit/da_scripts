# sh submit_job.sh <machine>
machine=$1
if [ -z $2 ]; then
   cat ${machine}_preamble config.sh > job.sh
else
   cat ${machine}_preamble2 config.sh > job.sh
fi
sbatch job.sh
