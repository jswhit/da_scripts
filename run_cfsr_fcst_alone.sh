#!/bin/sh
#PBS -A nggps_psd
#PBS -l partition=c4
##PBS -q batch
#PBS -q urgent
#PBS -l nodes=6:ppn=36
#PBS -l walltime=02:30:00
#PBS -N C384_cfsr_alone  
#PBS -e C384_cfsr_alone.err
#PBS -o C384_cfsr_alone.out
#PBS -S /bin/sh

export NODES=6
export corespernode=$PBS_NUM_PPN
export machine='gaea'

export exptname=C128_C384_test
export fg_only='true'

export charnanal="cfsr"
echo "charnanal = $charnanal"

export fg_only=true
export analdate=2002010500
export yr=`echo $analdate | cut -c1-4`
echo "$analdate run high-res control long fcst `date`"

export quilting='.false.'
export control_threads=1
export control_proc=216
export layout="6,6"

export LEVS=64
export FHMIN=3
export FHOUT=3
export FHMAX_LONG=48

export VERBOSE=YES

export rungfs='run_fv3_test.sh' # ensemble forecast
export replay_controlfcst='true' # only used if replay_controlfcst=true
 
export basedir=/lustre/f1/${USER}
export datadir=$basedir
export datapath="${datadir}/${exptname}"
export datapath2="${datapath}/${analdate}"
export obs_datapath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/gdas1bufr

export enkfscripts="/lustre/f1/unswept/Gary.Bates/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"

export execdir=${enkfscripts}/exec_${machine}
export enkfbin=${execdir}/global_enkf
export nemsioget=${execdir}/nemsio_get

export logdir="${datadir}/logs/${exptname}"
export hsidir="/3year/NCEPDEV/GEFSRR/Gary.Bates/${exptname}"

export FHOFFSET=0
export ANALINC=6
export analdatem1=`${incdate} $analdate -$ANALINC`
echo "Previous date: $analdatem1"

# model parameters for ensemble (rest set in $rungfs)
export fg_threads=1 # ens fcst threads

export RES_CTL=384 

mkdir -p ${datapath2}/${charnanal}
/bin/cp -f /lustre/f1/unswept/Gary.Bates/cfsr_inits/${yr}/C${RES_CTL}_${analdate}/control/* ${datapath2}/${charnanal}

export psautco_ctl="0.0008,0.0005"
export prautco_ctl="0.00015,0.00015"

# Model Physics Option
export imp_physics=11 # GFDL MP
## export imp_physics=99 # zhao-carr
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

export fv3gfspath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
export FCSTEXEC=${execdir}/${fv3exec}
export FIXGLOBAL=${fv3gfspath}/fix/fix_am

if [ $RES_CTL -eq 1534 ]; then
   export fv_sg_adj_ctl=600
   export dt_atmos_ctl=120
   export cdmbgwd_ctl="3.5,0.25"
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

# to turn off iau, use iau_delthrs=-1
export iau_delthrs="-1" # iau_delthrs < 0 turns IAU off
export iaufhrs="3,6,9"

csh ${enkfscripts}/run_long_fcst.csh

