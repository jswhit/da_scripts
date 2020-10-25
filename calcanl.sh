export LEVSp1=`expr $LEVS \+ 1`
SIGLEVEL=${SIGLEVEL:-${FIXGLOBAL}/global_hyblev.l${LEVSp1}.txt}
export CALCANLEXEC=${CALCANLEXEC:-${execdir}/calc_analysis.x}

DATA=$datapath2/calcanltmp$$
mkdir -p $DATA
pushd $DATA

# namelist /setup/ datapath, analysis_filename, firstguess_filename, increment_filename, fhr, use_nemsio_anl

/bin/rm -f calc_analysis.nml
/bin/rm -f $3
cat > calc_analysis.nml << EOF
&setup
  datapath="${datapath2}"
  firstguess_filename="${1}"
  increment_filename="${2}"
  analysis_filename="${3}"
  fhr=0
/
EOF
cat calc_analysis.nml

export OMP_NUM_THREADS=$corespernode
export OMP_STACKSIZE=256M
#$CALCANLEXEC
export PGM="$CALCANLEXEC"
export nprocs=1
export mpitaskspernode=1
${enkfscripts}/runmpi
ls -l

if [ $? -ne 0 ]; then
  exit 1
fi

if [ ! -s "${datapath2}/${3}" ]; then
   echo "output file ${3} not created"
   exit 1
fi

popd
/bin/rm -rf $DATA
exit 0
