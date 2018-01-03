echo "running on $machine using $NODES nodes"
ulimit -s unlimited

export exptname=C128_convonly
export cores=`expr $NODES \* $corespernode`

# check that value of NODES is consistent with PBS_NP on theia.
if [ "$machine" == 'theia' ]; then
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
export do_cleanup='true' # if true, create tar files, delete *mem* files.
export controlanal='false' # use gsi hybrid (if false, pure enkf is used)
export controlfcst='false' # if true, run dual-res setup with single high-res control
export cleanup_fg='true'
export cleanup_ensmean='true'
export cleanup_anal='true'
export cleanup_controlanl='true'
export cleanup_observer='true' 
export resubmit='true'
export ensmean_restart='false'
# for 'passive' or 'replay' cycling of control fcst 
# control forecast files have 'control2' suffix, instead of 'control'
# GSI observer will be run on 'control2' forecast
# this is for diagnostic purposes (to get GSI diagnostic files) 
export replay_controlfcst='false'
export replay_run_observer='false' # run observer on replay forecast
# python script checkdate.py used to check
# YYYYMMDDHH analysis date string to see if
# full ensemble should be saved to HPSS (returns 0 if 
# HPSS save should be done)
export save_hpss_subset="true" # save a subset of data each analysis time to HPSS
export run_long_fcst="false"  # spawn a longer control forecast at 00 and 12 UTC

# override values from above for debugging.
#export cleanup_ensmean='false'
#export cleanup_observer='false'
#export cleanup_anal='false'
#export cleanup_controlanl='false'
#export recenter_anal="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
 
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
   echo "machine must be 'wcoss', 'theia', or 'gaea', got $machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"
export corrlengthnh=1500
export corrlengthtr=1500
export corrlengthsh=1500
export lnsigcutoffnh=1.5
export lnsigcutofftr=1.5
export lnsigcutoffsh=1.5
export lnsigcutoffpsnh=3.0
export lnsigcutoffpstr=3.0
export lnsigcutoffpssh=3.0
export lnsigcutoffsatnh=3.0   
export lnsigcutoffsattr=3.0   
export lnsigcutoffsatsh=3.0   
export obtimelnh=1.e30       
export obtimeltr=1.e30       
export obtimelsh=1.e30       
export readin_localization=.false.
export massbal_adjust=.false.

# resolution of control and ensmemble.
export RES=128
export RES_CTL=384 

# this is set in ${machine_preamble} now

# model parameters for ensemble (rest set in $rungfs)
#if [ $RES -eq 384 ]; then
#  export enkf_threads=12 # threads for EnKF
#  export gsi_control_threads=4 # threads for GSI
#  export fg_proc=96 # number of total cores allocated to each enkf fg ens member. 
#  export fg_threads=1 # ens fcst threads
#  export write_groups=4 # write groups
#  export write_tasks=6 # write tasks
#  export layout="3,4" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
#elif [ $RES -eq 192 ]; then
#  export enkf_threads=2
#  export gsi_control_threads=2
#  export fg_proc=$corespernode 
#  export fg_threads=1 
#  if [ $corespernode -eq 24 ]; then
#     export write_groups=1
#     export write_tasks=6 
#     export layout="3, 1" 
#  elif [ $corespernode -eq 32 ]; then
#     export write_groups=1
#     export write_tasks=8 
#     export layout="2, 2" 
#  elif [ $corespernode -eq 36 ]; then
#     export write_groups=2
#     export write_tasks=6 
#     export layout="2, 2" 
#  else
#     echo "unknown corespernode"
#  exit 1
#  fi
#elif [ $RES -eq 96 ]; then
#  export enkf_threads=1
#  export gsi_control_threads=1
#  export fg_proc=24
#  export fg_threads=1 
#  export write_groups=1
#  export write_tasks=6 
#  export layout="3, 1"
#else
#  echo "compute parameters layout for resolution C$RES not set"
#  exit 1
#fi

#if [ $NODES -eq 20 ]; then
#  # 20 nodes, 2 threads
#  #export control_threads=2 # control forecast threads
#  #export control_proc=444   # total number of processors for control forecast
#  export control_threads=3
#  export control_proc=666
#  export write_groups_ctl=1 # write groups for control forecast.
#  export layout_ctl="6,6" # layout_x,layout_y (total # mpi tasks = $layout_x*$layout_y*6=($fg_proc/$fg_threads) - $write_tasks*$write_groups)
#elif [ $NODES -eq 40 ]; then
#  # 40 nodes, 2 threads
#  export control_threads=2 
#  export control_proc=876  
#  export write_groups_ctl=1
#  export layout_ctl="12, 6"
#elif [ $NODES -eq 80 ]; then
#  # 80 nodes, 2 threads
#  export control_threads=2
#  export control_proc=1740 
#  export write_groups_ctl=1
#  export layout_ctl="12, 12" 
#else
#  echo "processor layout for $NODES nodes not set"
#  exit 1
#fi

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
export SKEB=0.5
export SKEB_TSCALE=21600.
export SKEB_LSCALE=500.e3
export SKEBNORM=0
export SKEB_NPASS=30
export SKEB_VDOF=5

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
   export cdmbgwd="0.25,2.5"
elif [ $RES -eq 128 ]; then
   export JCAP=254 
   export LONB=512   
   export LATB=256  
   export fv_sg_adj=1500
   export dt_atmos=720
   export cdmbgwd="0.15,2.75"
elif [ $RES -eq 96 ]; then
   export JCAP=188 
   export LONB=384   
   export LATB=190  
   export fv_sg_adj=1800
   export dt_atmos=900
   export cdmbgwd="0.125,3.0"
else
   echo "model parameters for ensemble resolution C$RES_CTL not set"
   exit 1
fi

if [ $RES_CTL -eq 768 ]; then
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
   export LONB_CTL=1536
   export LATB_CTL=768
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
   echo "model parameters for control resolution C$RES_CTL not set"
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
export analpertwtnh=0.75
export analpertwtsh=0.75
export analpertwttr=0.75
export pseudo_rh=.false.
export use_qsatensmean=.true.
                                                                    
export letkf_flag=.false.
export nobsl_max=10000
export sprd_tol=6.0  
export varqc=.true.
export huber=.true.
export zhuberleft=1.1
export zhuberright=1.1

export biasvar=-500
export NOSAT=YES # no radiances assimilated (comment this out to get radiances)
if [ $controlanal == 'false' ] && [ $NOSAT == "NO" ];  then
   export lupd_satbiasc=.true.
   export numiter=4
else
   export lupd_satbiasc=.false.
   export numiter=1
fi
# iterate enkf in obspace for varqc
if [ $varqc == ".true." ]; then
  export numiter=5
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
   export gsipath=/scratch3/BMC/gsienkf/whitaker/gsi/EXP-enkflinhx-ncdiag
   export FIXFV3=${fv3gfspath}/fix/fix_fv3
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch3/BMC/gsienkf/whitaker/gsi/branches/EXP-enkflinhx/fix/crtm_2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'gaea' ]; then
# warning - these paths need to be updated on gaea
   export fv3gfspath=${basedir}/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
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
export HYBENSINFO=${enkfscripts}/global_hybens_info.l64.txt
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
export use_prepb_satwnd=.true.
export aircraft_bc=.false.
#export use_prepb_satwnd=.false.
#export aircraft_bc=.true.

cd $enkfscripts
echo "run main driver script"
csh main.csh
