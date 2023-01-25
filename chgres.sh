export LEVSp1=`expr $LEVS \+ 1`
SIGLEVEL=${SIGLEVEL:-${FIXGLOBAL}/global_hyblev.l${LEVSp1}.txt}
export CHGRESEXEC=${CHGRESEXEC:-${execdir}/enkf_chgres_recenter_nc.x}

DATA=$datapath2/chgrestmp$$
mkdir -p $DATA
pushd $DATA

ln -fs $1       atmanl_gsi
ln -fs $2       atmanl_ensmean
echo "terrain file/ref file atmanl_ensmean symlinked to $2"
echo "input file atmanl_gsi symlinked to $1"
echo "output file $3"

# namelist /chgres_setup/ i_output, j_output, input_file, output_file, &
#                      terrain_file, cld_amt, ref_file

/bin/rm -f chgres.nml
/bin/rm -f $3
cat > chgres.nml << EOF
&chgres_setup
  i_output=$LONB
  j_output=$LATB
  input_file="atmanl_gsi"
  output_file="${3}"
  terrain_file="atmanl_ensmean"
  ref_file="atmanl_ensmean"
/
EOF
cat chgres.nml

export OMP_NUM_THREADS=$corespernode
export OMP_STACKSIZE=256M
#$CHGRESEXEC
export PGM="$CHGRESEXEC chgres.nml"
export nprocs=1
export mpitaskspernode=1
${enkfscripts}/runmpi

if [ $? -ne 0 ]; then
  exit 1
fi
ls -l

if [ ! -s "${3}" ]; then
   echo "output file ${3} not created"
   exit 1
fi

popd
/bin/rm -rf $DATA
exit 0
