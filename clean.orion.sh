#!/bin/bash
set -x
echo "clean up files `date`"
cd ${datapath}
# save backup of next analysis time
tar -cvf backup_restart.tar ${analdatep1}
# scp to niagara?
#noaauser goes in config.sh 
#scp -r backup_restart.tar $noaauser@dtn-niagara.fairmont.rdhpcs.noaa.gov:/collab1/data/$noaauser/.
cd $datapath2
/bin/rm -rf *mem* # get rid of every member files
/bin/rm -f hostfile* fort* *log *lores nodefile* machinefile*
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
if [[ $cleanup_hybridtmp == 'true' ]]; then
   /bin/rm -rf *tmp*  # get rid of tmp directories
fi
# scp clean-up directory to niagara here?
#cd ..
# scp -r $analdate .... 
#scp -r $analdate/ $noaauser@dtn-niagara.fairmont.rdhpcs.noaa.gov:/collab1/data/$noaauser/.
echo "unwanted files removed `date`"
