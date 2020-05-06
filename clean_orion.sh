echo "clean up files `date`"
cd ${datapath}
# save backup of next analysis time
tar -cvf backup_restart.tar ${analdatep1}
# scp to niagara?
cd $datapath2
/bin/rm -rf *mem* # get rid of every member files
/bin/rm -f hostfile* fort* *log *lores nodefile* machinefile*
/bin/rm -f ozinfo convinfo satinfo scaninfo anavinfo
/bin/rm -rf *tmp*  # get rid of tmp directories
echo "unwanted files removed `date`"
