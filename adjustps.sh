export nprocs=1
export mpitaskspernode=1
export OMP_NUM_THREADS=1
export PGM="${execdir}/adjustps.x $1 $2 $3"
${enkfscripts}/runmpi
