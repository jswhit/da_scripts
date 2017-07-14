#BSUB -W 4:00                    # wall clock time 
#BSUB -o tarit_longfcst.stdout          # stdout
#BSUB -e tarit_longfcst.stderr          # stderr
#BSUB -J tarit                 # jobname
#BSUB -q "dev_transfer"         # job queue 
#BSUB -P GFS-T2O                 # project code 
#BSUB -M 1000                    # Memory req's for serial portion
export NODES=1
module load hpss
env
hsi ls -l $hsidir
hsi mkdir ${hsidir}/
cd ${datapath2}
htar -cvf ${hsidir}/${analdate}_longfcst.tar longfcst
