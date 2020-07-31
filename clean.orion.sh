#!/bin/bash
set -x
echo "clean up files `date`"
cd ${datapath} #cd /work/noaa/fv3-cam/dlippi/C192_hybgain_netcdf-owiau-test2
# save backup of next analysis time
tar -cvf backup_restart.tar ${analdatep1}
# scp to niagara?
#noaauser goes in config.sh 
#cd ..
#sbatch -p service -A ${account} -q batch -o ${datapath}/${analdate}/logs/backup_restart.out -n1 --wrap "rsync -R ${exptname}/backup_restart.tar  ${noaauser}@dtn-niagara.fairmont.rdhpcs.noaa.gov:/collab1/data/${noaauser}"

cd $datapath2 #cd /work/noaa/fv3-cam/dlippi/C192_hybgain_netcdf-owiau-test2/2020031310/
/bin/rm -rf *mem* # get rid of every member files
/bin/rm -f hostfile* fort* *log *lores nodefile* machinefile*
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
if [[ $cleanup_hybridtmp == 'true' ]]; then
   /bin/rm -rf *tmp*  # get rid of tmp directories
fi
# scp clean-up directory to niagara here?
# scp -r $analdate .... 
cd ../..
sbatch -p service -A ${account} -q batch -o ${datapath}/${analdate}/logs/backup.out -n1 --wrap "rsync -aRL ${exptname}/${analdate} ${noaauser}@dtn-niagara.fairmont.rdhpcs.noaa.gov:/collab1/data/${noaauser}"
echo "unwanted files removed `date`"
