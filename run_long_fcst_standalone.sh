#PBS -l nodes=20:ppn=24
#PBS -l walltime=2:00:00
#PBS -A gsienkf
##PBS -q debug
#PBS -N longfcst_standalone
#PBS -S /bin/bash
#PBS -o longfcst_standalone.stdout
#PBS -e longfcst_standalone.stderr
export NODES=20
export corespernode=24
export machine='theia'
echo "running on $machine using $NODES nodes"
ulimit -s unlimited

export analdate=2016010500

export fg_only='false'

export exptname=C192C384_test_iau2b
export cores=`expr $NODES \* $corespernode`

# check that value of NODES is consistent with PBS_NP on theia and jet.
if [ "$machine" != 'wcoss' ]; then
   if [ $PBS_NP -ne $cores ]; then
     echo "NODES = ${NODES} PBS_NP = ${PBS_NP} cores = ${cores}"
     echo "NODES set incorrectly in preamble"
     exit 1
   fi
fi
export KMP_AFFINITY=disabled

export rungfs='run_fv3.sh' # ensemble forecast
export replay_controlfcst='true' # only used if replay_controlfcst=true
 
if [ "$machine" == 'wcoss' ]; then
   export basedir=/gpfs/hps2/esrl/gefsrr/noscrub/${USER}
   export datadir=/gpfs/hps2/ptmp/${USER}
   export hsidir="/3year/NCEPDEV/GEFSRR/${USER}/${exptname}"
   module load hpss
   module load grib_util/1.0.3
   module load nco-gnu-sandybridge
elif [ "$machine" == 'theia' ]; then
   export basedir=/scratch3/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   module load wgrib
   export WGRIB=`which wgrib`
   module load nco
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f1/unswept/${USER}/nggps
   export datadir=$basedir
   export hsidir="/2year/BMC/gsienkf/whitaker/gaea/${exptname}"
elif [ "$machine" == 'jet' ]; then
   export basedir=/lfs3/projects/gfsenkf/${USER}
   export datadir=$basedir
   export hsidir="/HFIP/gfsenkf/2year/${USER}/${exptname}"
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

if [ $NODES -eq 20 ]; then
# 20 nodes, 2 threads
export control_threads=2 # control forecast threads
export control_proc=444  
export write_groups_ctl=1
export layout_ctl="6, 6" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($control_proc-$write_tasks)/control_threads)
elif [ $NODES -eq 40 ]; then
# 40 nodes, 2 threads
export control_threads=2 # control forecast threads
export control_proc=876  
export write_groups_ctl=1
export layout_ctl="12, 6" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($control_proc-$write_tasks)/control_threads)
else
echo "processor layout for $NODES nodes not set"
exit 1
fi

export RES=192 
export RES_CTL=384 
export psautco="6.0d-4,3.0d-4"
export zhao_mic=T

if [ $zhao_mic == "F" ]; then
   export ncld=5
   export nwat=6
   export cal_pre=F
   export dnats=1
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
if [ $RES -eq 384 ]; then
   export JCAP=878 
   export LONB=1760  
   export LATB=880  
   export fv_sg_adj=600
   export dt_atmos=225
   export cdmbgwd="1.0,1.2"
elif [ $RES -eq 192 ]; then
   export JCAP=382 
   export LONB=768   
   export LATB=384  
   export fv_sg_adj=900
   export dt_atmos=450
   export cdmbgwd="0.25,2.0"
elif [ $RES -eq 96 ]; then
   export JCAP=126 
   export LONB=384   
   export LATB=190  
   export fv_sg_adj=1800
   export dt_atmos=900
   export cdmbgwd="0.125,3.0"
else
   echo "unknown RES=${RES}"
   exit 1
fi

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
   export FIXGLOBAL=${basedir}/fv3gfs/global_shared.v15.0.0/fix/fix_am
   export FIXFV3=${basedir}/fv3gfs/fix_fv3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
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
export FHOUT=6
export quilting=.true.
export VERBOSE=YES
csh ${enkfscripts}/run_long_fcst.csh

#export analdate=`${incdate} $analdate 12`
#echo "export analdate=${analdate}" > ${datapath}/analdate.sh
#cd ${enkfscripts}
#if ($analdate < '2016011712') qsub run_long_fcst_test.sh
