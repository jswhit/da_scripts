echo "running on $machine using $NODES nodes"
ulimit -s unlimited

export exptname=C384C192_test_iau
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

export fg_gfs="run_ens_fv3.csh"
export ensda="enkf_run.csh"
export rungsi='run_gsi_4densvar.sh'
export rungfs='run_fv3.sh' # ensemble forecast

export recenter_anal="true" # recenter enkf analysis around GSI hybrid 4DEnVar analysis
# recenter enkf forecasts around control forecast (needed for dual-res and IAU)
# should be be 'false' for passive replay cycling of control forecast
export recenter_fcst="false" 
export do_cleanup='true' # if true, create tar files, delete *mem* files.
export controlanal='true' # use gsi hybrid (if false, pure enkf is used)
export controlfcst='true' # if true, run dual-res setup with single high-res control
export cleanup_fg='true'
export cleanup_ensmean='true'
export cleanup_anal='true'
export cleanup_controlanl='true'
export resubmit='true'
# for 'passive' or 'replay' cycling of control fcst 
# control forecast files have 'control2' suffix, instead of 'control'
# GSI observer will be run on 'control2' forecast
# this is for diagnostic purposes (to get GSI diagnostic files) 
export replay_controlfcst='true'
if ($replay_controlfcst == 'true')
  echo "resetting recenter_fcst to false for passive replay of control forecast"
  export recenter_fcst='false'
endif
export cleanup_observer='true' # only used if replay_controlfcst=true
# python script checkdate.py used to check
# YYYYMMDDHH analysis date string to see if
# full ensemble should be saved to HPSS (returns 0 if 
# HPSS save should be done)
export save_hpss_subset="true" # save a subset of data each analysis time to HPSS

# override values from above for debugging.
#export cleanup_ensmean='false'
#export cleanup_controlanl='false'
#export cleanup_anal='false'
#export cleanup_observer='true'
#export recenter_fcst="false"
#export recenter_anal="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
 
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
export logdir="${datadir}/logs/${exptname}"
export corrlengthnh=1250
export corrlengthtr=1250
export corrlengthsh=1250
export lnsigcutoffnh=1.25
export lnsigcutofftr=1.25
export lnsigcutoffsh=1.25
export lnsigcutoffpsnh=1.25
export lnsigcutoffpstr=1.25
export lnsigcutoffpssh=1.25
export lnsigcutoffsatnh=1.25  
export lnsigcutoffsattr=1.25  
export lnsigcutoffsatsh=1.25  
export obtimelnh=1.e30       
export obtimeltr=1.e30       
export obtimelsh=1.e30       
export readin_localization=.true.
export massbal_adjust=.false.

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
elif [ $RES_CTL -eq 384 ]; then
   export fv_sg_adj_ctl=600
   export dt_atmos_ctl=225
   export cdmbgwd_ctl="1.0,1.2"
elif [ $RES_CTL -eq 192 ]; then
   export fv_sg_adj_ctl=900
   export dt_atmos_ctl=450
   export cdmbgwd_ctl="0.25,2.0"
elif [ $RES_CTL -eq 96 ]; then
   export fv_sg_adj_ctl=1800
   export dt_atmos_ctl=900
   export cdmbgwd_ctl="0.125,3.0"
else
   echo "unknown RES_CTL=${RES_CTL}"
   exit 1
fi
export FHCYC=0 # run global_cycle instead of gcycle inside model

export LONA=$LONB
export LATA=$LATB      

export ANALINC=6

export LEVS=64
export FHMIN=3
export FHMAX=9
export FHOUT=3
FHMAXP1=`expr $FHMAX + 1`
export enkfstatefhrs=`python -c "print range(${FHMIN},${FHMAXP1},${FHOUT})" | cut -f2 -d"[" | cut -f1 -d"]"`
export iaufhrs="3,6,9"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off
# dump increment in one time step (for debugging)
#export iaufhrs="6"
#export iau_delthrs=0.25
# to turn off iau, use iau_delthrs=-1
#export iau_delthrs=-1

# other model variables set in ${rungfs}
# other gsi variables set in ${rungsi}

export SMOOTHINF=35
export npts=`expr \( $LONA \) \* \( $LATA \)`
export obs_datapath=${basedir}/gdas1bufr
#export obs_datapath=/gpfs/hps2/esrl/gefsrr/noscrub/cfsr_dumps
export RUN=gdas1 # use gdas obs
export reducedgrid=.false.
export univaroz=.false.

export iassim_order=0

export covinflatemax=1.e2
export covinflatemin=1.0                                            
export analpertwtnh=0.85
export analpertwtsh=0.85
export analpertwttr=0.85
export pseudo_rh=.true.
export use_qsatensmean=.true.
                                                                    
export letkf_flag=.false.
export nobsl_max=10000
export sprd_tol=1.e30
export varqc=.false.
export huber=.false.
export zhuberleft=1.e10
export zhuberright=1.e10

export biasvar=-500
if [ $controlanal == 'false' ];  then
   export lupd_satbiasc=.true.
   export numiter=4
else
   export lupd_satbiasc=.false.
   export numiter=1
fi
# use pre-generated bias files.
#export lupd_satbiasc=.false.
#export numiter=1
#export biascorrdir=<exptdir>


# turn on enkf analog of VarQC
#export sprd_tol=10.
#export varqc=.true.
#export huber=.true.
#export zhuberleft=1.1
#export zhuberright=1.1
                                                                    
export nanals=80                                                    
                                                                    
export paoverpb_thresh=0.99  # set to 1.0 to use all the obs in serial EnKF
export saterrfact=1.0
export deterministic=.true.
export sortinc=.true.
                                                                    
export nitermax=2 

export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"

if [ "$machine" == 'theia' ]; then
   export fv3gfspath=/scratch4/NCEPDEV/global/save/glopara/svn/fv3gfs/trunk/global_shared.v15.0.0
   export gsipath=/scratch3/BMC/gsienkf/whitaker/gsi/branches/EXP-enkflinhx
   export FIXFV3=${fv3gfspath}/fix/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm_2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'gaea' ]; then
# warning - these paths need to be updated on gaea
   export FIXGLOBAL=${basedir}/fv3gfs/global_shared.v15.0.0/fix/fix_am
   export FIXFV3=${basedir}/fv3gfs/fix_fv3
   export gsipath=${basedir}/gsi/branches/EXP-enkflinhx
   export gsiexec=${gsipath}/src/global_gsi
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm-2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'wcoss' ]; then
   export fv3gfspath=/gpfs/hps3/emc/global/noscrub/emc.glopara/svn/fv3gfs
   export gsipath=/gpfs/hps2/esrl/gefsrr/noscrub/Jeffrey.S.Whitaker/gsi/ProdGSI
   export FIXFV3=${fv3gfspath}/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm_2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'jet' ]; then
   echo "jet not yet supported"
   exit 1
else
   echo "${machine} unsupported machine"
   exit 1
fi

#export ANAVINFO=${enkfscripts}/global_anavinfo.l${LEVS}.txt
#export ANAVINFO_ENKF=${ANAVINFO}
#export HYBENSINFO=${enkfscripts}/global_hybens_info.l${LEVS}.txt
#export CONVINFO=${fixgsi}/global_convinfo.txt
#export OZINFO=${enkfscripts}/global_ozinfo.txt
# set SATINFO in main.csh

export ANAVINFO=${enkfscripts}/global_anavinfo.l64.txt
export ANAVINFO_ENKF=${ANAVINFO}
export HYBENSINFO=${fixgsi}/global_hybens_info.l64.txt
export CONVINFO=${fixgsi}/global_convinfo.txt
export OZINFO=${fixgsi}/global_ozinfo.txt
export SATINFO=${fixgsi}/global_satinfo.txt
# comment out SATINFO in main.csh

# parameters for hybrid
export beta1_inv=0.125    # 0 means all ensemble, 1 means all 3DVar.
#export beta1_inv=0 # non-hybrid, pure ensemble
# these are only used if readin_localization=F
export s_ens_h=485      # a gaussian e-folding, similar to sqrt(0.15) times Gaspari-Cohn length
export s_ens_v=-0.485   # in lnp units.
# NOTE: most other GSI namelist variables are in ${rungsi}
#export use_prepb_satwnd=.true.
#export aircraft_bc=.false.
export use_prepb_satwnd=.false.
export aircraft_bc=.true.

cd $enkfscripts
echo "run main driver script"
csh main.csh
