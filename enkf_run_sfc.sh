#!/bin/sh

export nprocs=`expr $cores \/ $enkf_threads`
export mpitaskspernode=`expr $corespernode \/ $enkf_threads`
export OMP_NUM_THREADS=$enkf_threads
export OMP_STACKSIZE=512M
export MKL_NUM_THREADS=1
source $MODULESHOME/init/sh
module list

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

for nfhr in $iaufhrs2; do
  charfhr="fhr"`printf %02i $nfhr`
  # check output files.
  nanal=1
  filemissing='no'
  while [ $nanal -le $nanals ]; do
     charnanal="mem"`printf %03i $nanal`
     analfile="${datapath2}/${sfcanalfileprefix}_${analdate}_${charfhr}_${charnanal}"
     if [ ! -s $analfile ]; then
        filemissing='yes'
     fi
     nanal=$((nanal+1))
  done
done


if [ $filemissing == 'yes' ]; then

echo "computing enkf sfc update..."

date
cd ${datapath2}

cat <<EOF > enkf.nml
 &nam_enkf
  datestring="$analdate",datapath="$datapath2",univaroz=.false.,numiter=0,
  analpertwtnh=$analpertwtnh,analpertwtsh=$analpertwtsh,analpertwttr=$analpertwttr,
  analpertwtnh_rtpp=$analpertwtnh_rtpp,analpertwtsh_rtpp=$analpertwtsh_rtpp,analpertwttr_rtpp=$analpertwttr_rtpp,
  covinflatemax=$covinflatemax,covinflatemin=$covinflatemin,pseudo_rh=.false.,
  corrlengthnh=$corrlength_sfc,corrlengthsh=$corrlength_sfc,corrlengthtr=$corrlength_sfc,
  lnsigcutoffnh=1.e30,lnsigcutoffsh=1.e30,lnsigcutofftr=1.e30,
  lnsigcutoffsatnh=1.e30,lnsigcutoffsatsh=1.e30,lnsigcutoffsattr=1.e30,
  lnsigcutoffpsnh=1.e30,lnsigcutoffpssh=1.e30,lnsigcutoffpstr=1.e30,
  nlons=$LONA,nlats=$LATA,smoothparm=$SMOOTHINF,letkf_bruteforce_search=${letkf_bruteforce_search},
  readin_localization=$readin_localization,saterrfact=$saterrfact,
  paoverpb_thresh=$paoverpb_thresh,letkf_flag=.false.,denkf=$denkf,
  getkf_inflation=$getkf_inflation,letkf_novlocal=.true.,modelspace_vloc=.false.,save_inflation=.false.,
  reducedgrid=${reducedgrid},nlevs=$LEVS,nanals=$nanals,deterministic=$deterministic,imp_physics=$imp_physics,
  diagprefix=${diagprefix_sfc},lobsdiag_forenkf=.false.,write_spread_diag=.false.,netcdf_diag=.true.,
  sortinc=$sortinc,nhr_anal=$iaufhrs,nhr_state=$enkfstatefhrs,getkf=$getkf,
  use_correlated_oberrs=.false.,use_gfs_ncio=.true.,nccompress=T,paranc=F,write_fv3_incr=${write_fv3_increment_sfc},write_ensmean=${write_ensmean},
  adp_anglebc=.true.,angord=4,newpc4pred=.true.,use_edges=.false.,emiss_bc=.true.,biasvar=-500,nobsl_max=$nobsl_max,use_qsatensmean=.true.,
  ${WRITE_INCR_ZERO},global_2mDA=.true.
 /
 &satobs_enkf
 /
 &END
 &ozobs_enkf
 /
 &END
EOF

cat enkf.nml

cp ${enkfscripts}/vlocal_eig_L${LEVS}.dat ${datapath2}/vlocal_eig.dat

/bin/rm -f ${datapath2}/enkf.log
/bin/mv -f ${current_logdir}/ensda_sfc.out ${current_logdir}/ensda_sfc.out.save
export PGM=$enkfbin
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"

# use same number of tasks on every node.
export nprocs=`expr $cores \/ $OMP_NUM_THREADS`
export mpitaskspernode=`expr $corespernode \/ $OMP_NUM_THREADS`
echo "running with $OMP_NUM_THREADS threads ..."
${enkfscripts}/runmpi > ${current_logdir}/ensda_sfc.out 2>&1

if [ ! -s ${datapath2}/enkf.log ]; then
   echo "no enkf sfc log file found"
   exit 1
fi

else
echo "enkf sfc update already done..."
fi # filemissing='yes'

# check output files again.
nanal=1
filemissing='no'
while [ $nanal -le $nanals ]; do
   charnanal="mem"`printf %03i $nanal`
   analfile=${datapath2}/${sfcanalfileprefix}_${analdate}_${charfhr}_${charnanal}
   if [ ! -s $analfile ]; then
     filemissing='yes'
   fi
   nanal=$((nanal+1))
done

if [ $filemissing == 'yes' ]; then
    echo "there are output files missing!"
    exit 1
else
    echo "all output files seem OK `date`"
fi
exit 0
