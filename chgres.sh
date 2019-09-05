export LEVSp1=`expr $LEVS \+ 1`
SIGLEVEL=${SIGLEVEL:-${FIXGLOBAL}/global_hyblev.l${LEVSp1}.txt}
export CHGRESEXEC=${CHGRESEXEC:-${execdir}/chgres_recenter.exe}

DATA=$datapath2/chgrestmp$$
mkdir -p $DATA
pushd $DATA

ls -l $1
ls -l $2
ln -fs $1       atmanl_gsi
ln -fs $2       atmanl_ensmean

rm -f fort.43
cat > fort.43 << EOF
&nam_setup
  i_output=$LONB
  j_output=$LATB
  input_file="atmanl_gsi"
  output_file="atmanl_gsi_ensres"
  terrain_file="atmanl_ensmean"
  vcoord_file="$SIGLEVEL"
/
EOF
cat fort.43

export OMP_NUM_THREADS=$corespernode
export OMP_STACKSIZE=256M
#$CHGRESEXEC
export PGM=$CHGRESEXEC
export nprocs=1
export mpitaskspernode=1
${enkfscripts}/runmpi

if [ $? -ne 0 ]; then
  exit 1
fi

if [ -s atmanl_gsi_ensres ]; then
   mv atmanl_gsi_ensres $3
else
   popd
   /bin/rm -rf $DATA
   exit 1
fi

popd
/bin/rm -rf $DATA
exit 0
