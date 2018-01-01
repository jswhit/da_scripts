#!/bin/sh
#PBS -A nggps_psd
#PBS -l partition=c4
#PBS -q batch
#PBS -l nodes=20
#PBS -l walltime=01:30:00
#PBS -N  C384_longfcst  
#PBS -e  C384_longfcst.err
#PBS -o  C384_longfcst.out
#PBS -S /bin/sh
export NODES=$PBS_NUM_NODES
export corespernode=$PBS_NUM_PPN
export machine='gaea'
echo "running on $machine using $NODES nodes"
ulimit -s unlimited

export analdate=2016010112

export fg_only='false'

export exptname=C384C128_test_iau
export cores=`expr $NODES \* $corespernode`

# check that value of NODES is consistent with PBS_NP on theia and jet.
if [ "$machine" != 'wcoss' ]; then
   if [ $PBS_NP -ne $cores ]; then
     echo "NODES = ${NODES} PBS_NP = ${PBS_NP} cores = ${cores}"
     echo "NODES set incorrectly in preamble"
     exit 1
   fi
fi

export rungfs='run_fv3.sh' # ensemble forecast
export replay_controlfcst='false' # only used if replay_controlfcst=true
export controlfcst='true'
 
if [ "$machine" == 'wcoss' ]; then
   export basedir=/gpfs/hps2/esrl/gefsrr/noscrub/${USER}
   export datadir=/gpfs/hps2/ptmp/${USER}
   export hsidir="/3year/NCEPDEV/GEFSRR/${USER}/${exptname}"
elif [ "$machine" == 'theia' ]; then
   export basedir=/scratch3/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f1/unswept/${USER}/fv3_reanl
   export datadir=$basedir
   export hsidir="/2year/BMC/gsienkf/whitaker/gaea/${exptname}"
else
   echo "machine must be 'wcoss', 'theia', or 'jet', got $machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
#. ${datapath}/analdate.sh
export datapath2="${datapath}/${analdate}"
export ANALINC=6
export FHOFFSET=`expr $ANALINC \/ 2`
export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"
export analdatem1=`${incdate} $analdate -$ANALINC`
export analdatep1=`${incdate} $analdate $ANALINC`
export analdatem3=`${incdate} $analdate -$FHOFFSET`
export analdatep1m3=`${incdate} $analdate $FHOFFSET`
export hrp1=`echo $analdatep1 | cut -c9-10`
export hrm1=`echo $analdatem1 | cut -c9-10`
export hr=`echo $analdate | cut -c9-10`
export datapathp1="${datapath}/${analdatep1}/"
export datapathm1="${datapath}/${analdatem1}/"
export logdir="${datadir}/logs/${exptname}"
echo "analdate = $analdate"
echo "analdatep1 = $analdatep1"

# model parameters for ensemble (rest set in $rungfs)
export fg_proc=24 # number of total cores allocated to each enkf fg ens member. 
export fg_threads=1 # ens fcst threads
export write_groups=1
export write_tasks=6 # write tasks
export layout="3, 1" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc-$write_tasks)/fg_threads)

# for control forecast
if [ $NODES -eq 10 ]; then
  # 20 nodes, 2 threads
  #export control_threads=2 # control forecast threads
  #export control_proc=444   # total number of processors for control forecast
  export control_threads=1
  if [ $quilting == ".true."]; then
  export control_proc=312
  export write_groups=4 # write groups for control forecast.
  export layout_ctl="6,8" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
  else
  export control_proc=360
  export layout_ctl="6,10" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
  fi
elif [ $NODES -eq 20 ]; then
  # 20 nodes, 2 threads
  #export control_threads=2 # control forecast threads
  #export control_proc=444   # total number of processors for control forecast
  if [ $quilting == ".true." ]; then
  export control_threads=3
  export control_proc=666
  export write_groups=1 # write groups for control forecast.
  export layout_ctl="6,6" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
  else
  export control_threads=2
  export control_proc=720
  export layout_ctl="6,10" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
  fi
else
  echo "processor layout for $NODES nodes not set"
  exit 1
fi

export RES=128 
export RES_CTL=384 
export psautco="0.0008,0.0005"
export prautco="0.00015,0.00015"
export imp_physics=99 # zhao-carr
#export imp_physics=11 # GFDL MP

if [ $imp_physics == "11" ]; then
   export ncld=5
   export nwat=6
   export cal_pre=F
   export dnats=1
   export do_sat_adj=".true."
   export random_clds=".false."
   export cnvcld=".false."
else
   export ncld=1
   export nwat=2
   export cal_pre=T
   export dnats=0
fi
export k_split=1
export n_split=6
export hydrostatic=F
if [ $hydrostatic == 'T' ];  then
   export fv3exec='fv3-hydro.exe'
   export hord_mt=10
   export hord_vt=10
   export hord_tm=10
   export hord_dp=-10
   export vtdm4=0.05
   export consv_te=0
else
   export fv3exec='fv3-nonhydro.exe'
   export hord_mt=5
   export hord_vt=5
   export hord_tm=5
   export hord_dp=-5
   export vtdm4=0.06
   export consv_te=1
fi

export SPPT=0.8
export SPPT_TSCALE=21600.
export SPPT_LSCALE=500.e3
export SHUM=0.006
export SHUM_TSCALE=21600.
export SHUM_LSCALE=500.e3
export SKEB=1.0
export SKEB_TSCALE=21600.
export SKEB_LSCALE=500.e3
export SKEBNORM=0
export SKEB_NPASS=30
export SKEB_VDOF=5

# Assimilation parameters
export enkf_threads=2 
export gsi_control_threads=2

# resolution dependent model parameters

if [ $RES_CTL -eq 1534 ]; then
   export fv_sg_adj_ctl=600
   export dt_atmos_ctl=120
   export cdmbgwd_ctl="3.5,0.25"
   export psautco_ctl="0.0008,0.0005"
   export prautco_ctl="0.00015,0.00015"
   export LONB_CTL=3072
   export LATB_CTL=1536
elif [ $RES_CTL -eq 384 ]; then
   export fv_sg_adj_ctl=600
   export dt_atmos_ctl=225
   export cdmbgwd_ctl="1.0,1.2"
   export LONB_CTL=1760
   export LATB_CTL=880
elif [ $RES_CTL -eq 192 ]; then
   export fv_sg_adj_ctl=900
   export dt_atmos_ctl=450
   export cdmbgwd_ctl="0.25,2.0"
   export LONB_CTL=768  
   export LATB_CTL=384
elif [ $RES_CTL -eq 96 ]; then
   export fv_sg_adj_ctl=1800
   export dt_atmos_ctl=900
   export cdmbgwd_ctl="0.125,3.0"
   export LONB_CTL=384  
   export LATB_CTL=192
else
   echo "unknown RES_CTL=${RES_CTL}"
   exit 1
fi
export FHCYC=0 # run global_cycle instead of gcycle inside model

export LEVS=64
export FHMIN=3
export FHMAX=9
export FHOUT=3
export iaufhrs="3,6,9"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off
# dump increment in one time step (for debugging)
#export iaufhrs="6"
#export iau_delthrs=0.25
# to turn off iau, use iau_delthrs=-1
#export iau_delthrs=-1

if [ "$machine" == 'theia' ]; then
   export fv3gfspath=/scratch4/NCEPDEV/global/save/glopara/svn/fv3gfs/trunk/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'gaea' ]; then
# warning - these paths need to be updated on gaea
   export fv3gfspath=${basedir}/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=${basedir}/ProdGSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'wcoss' ]; then
   export fv3gfspath=/gpfs/hps3/emc/global/noscrub/emc.glopara/svn/fv3gfs
   export FIXFV3=${fv3gfspath}/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'jet' ]; then
   echo "jet not yet supported"
   exit 1
else
   echo "${machine} unsupported machine"
   exit 1
fi

echo "$analdate run high-res control long fcst `date`"
export FHMAX_LONG=120 
export FHOUT=3
export quilting=.false.
export VERBOSE=YES
echo "csh ${enkfscripts}/run_long_fcst.csh"
csh ${enkfscripts}/run_long_fcst.csh
exit

export analdate=`${incdate} $analdate 12`
echo "export analdate=${analdate}" > ${datapath}/analdate.sh
cd ${enkfscripts}
if [ $analdate -lt 2016012000 ]; then
  qsub run_long_fcst_test.sh
fi
