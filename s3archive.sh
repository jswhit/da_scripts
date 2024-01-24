# need envars:  analdate, datapath, s3path

which aws
if [ $? -ne 0 ]; then
   echo "SLURM_CLUSTER_NAME=$SLURM_CLUSTER_NAME"
   if  [ $SLURM_CLUSTER_NAME == 'es' ]; then #
      #source /lustre/f2/dev/role.epic/contrib/Lmod_init.sh
      #module use /lustre/f2/dev/wpo/role.epic/contrib/spack-stack/c4/modulefiles
      #module use /lustre/f2/dev/wpo/role.epic/contrib/spack-stack/c4/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
      #module load stack-intel/2022.0.2
      module use /ncrc/proj/epic/spack-stack/spack-stack-1.5.1/envs/unified-env/install/modulefiles/Core
      module load stack-intel/2023.1.0
      module load awscli
   elif [ $SLURM_CLUSTER_NAME == 'hercules' ]; then
      module purge
      module use /work/noaa/epic/role-epic/spack-stack/hercules/modulefiles
      module use /work/noaa/epic/role-epic/spack-stack/hercules//spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
      module load stack-intel/2021.9.0
      module load awscli
   else
      echo "cluster must be 'hercules' or 'es' (gaea)"
      exit 1
   fi
fi
which aws
if [ $? -ne 0 ]; then
   echo "awscli not found"
   exit 1
fi

cd $datapath
MM=`echo $analdate | cut -c5-6`
YYYY=`echo $analdate | cut -c1-4`
s3path=s3://noaa-reanalyses-pds/analyses/scout_runs/GSI3DVar/1979stream/${YYYY}/${MM}/${analdate}/
aws s3 cp --recursive --quiet ${analdate} $s3path --profile aws-nnja

if [ $? -ne 0 ]; then
  echo "s3 archive failed "$filename
  exitstat=1
else
  echo "s3 archive succceeded "$filename
  echo "data written to ${s3path}"
  aws s3 ls --no-sign-request $s3path
  # remove everything except logs, gsistats and  abias* files
  /bin/rm -f ${analdatem1}/*diag*nc* ${analdate}/sfg* ${analdate}/bfg* ${analdate}/sanl* ${analdate}/gsiparm.anl
  /bin/rm -rf ${analdate}/control
fi
exit $exitstat
