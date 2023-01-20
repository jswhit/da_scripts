# hybrid gain GSI(3DVar)/EnKF workflow
export cores=`expr $NODES \* $corespernode`
echo "running on $machine using $NODES nodes and $cores CORES"

export ndates_job=1 # number of DA cycles to run in one job submission
# resolution of control and ensmemble.
export RES=192 
export RES_CTL=384
# Penney 2014 Hybrid Gain algorithm with beta_1=1.0
# beta_2=alpha and beta_3=0 in eqn 6 
# (https://journals.ametsoc.org/doi/10.1175/MWR-D-13-00131.1)
export hybgain="true" # hybrid gain approach, if false use hybrid covariance
export alpha=200 # percentage of 3dvar increment (beta_2*1000) 
export beta=1000 # percentage of enkf increment (*10)
# if replay_controlfcst='true', weight given to ens mean vs control 
# forecast in recentered backgrond ensemble (x100).  if recenter_control_wgt=0, then
# no recentering is done. If recenter_control_wgt=100, then the background
# ensemble is recentered around the control forecast.
# recenter_control_wgt=recenter_ensmean_wgt=50, then the background ensemble
# is recentered around the average of the (upscaled) control forecast and the
# original ensemble mean.
# if replay_controlfcst='false', not used for forecast.
# also used to control weights for recentering of enkf analysis if hybgain='false'
# in this case, to recenter around EnVar analysis set recenter_control_wgt=100
export recenter_control_wgt=100
export recenter_ensmean_wgt=`expr 100 - $recenter_control_wgt`
export exptname="C${RES}_hybgain"
# for 'passive' or 'replay' cycling of control fcst 
export replay_controlfcst='false'
export enkfonly='false' # pure EnKF

export fg_gfs="run_ens_fv3.sh"
export ensda="enkf_run.sh"
export rungsi='run_gsi_4densvar.sh'
export rungfs='run_fv3.sh' # ensemble forecast

export do_cleanup='true' # if true, create tar files, delete *mem* files.
export cleanup_fg='true'
export cleanup_ensmean='true'
export cleanup_anal='true'
export cleanup_controlanl='true'
export cleanup_observer='true' 
export resubmit='true'
export replay_run_observer='false' # run observer on replay control forecast
# python script checkdate.py used to check
# YYYYMMDDHH analysis date string to see if
# full ensemble should be saved to HPSS (returns 0 if 
# HPSS save should be done)
if [ $machine == "orion" ]; then
   export save_hpss_subset="false" # save a subset of data each analysis time to HPSS
   export save_hpss="false"
else
   export save_hpss_subset="true" # save a subset of data each analysis time to HPSS
   export save_hpss="true"
fi
export ensmean_restart='false'
export recenter_anal="true"
export recenter_fcst="false"
export controlanal="false" # hybrid-cov high-res control analysis as in ops
# controlanal takes precedence over hybgain
# (hybgain will be set to false if controlanal=true)

# override values from above for debugging.
#export cleanup_ensmean='false'
#export recenter_fcst="false"
#export cleanup_controlanl='false'
#export cleanup_observer='false'
#export cleanup_anal='false'
#export recenter_anal="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
#export save_hpss_subset="false" # save a subset of data each analysis time to HPSS
#export save_hpss="false"

source $MODULESHOME/init/sh
if [ "$machine" == 'hera' ]; then
   export basedir=/scratch2/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/scratch1/NCEPDEV/global/glopara/dump
   module purge
   module use /scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack/modulefiles/stack
   module load hpc/1.1.0
   module load hpc-intel/18.0.5.274
   module load hpc-impi/2018.0.4
   module load hdf5/1.10.6
   module load netcdf/4.7.4
   module load pio/2.5.2
   module load esmf/8_2_0_beta_snapshot_14
   module load fms/2021.03
   module load wgrib
   export WGRIB=`which wgrib`
elif [ "$machine" == 'orion' ]; then
   export basedir=/work2/noaa/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/work/noaa/rstprod/dump
   ulimit -s unlimited
   source $MODULESHOME/init/sh
   module use /apps/contrib/NCEP/libs/hpc-stack/modulefiles/stack
   module load hpc/1.1.0
   module load hpc-intel/2018.4
   module unload mkl/2020.2
   module load mkl/2018.4
   module load hpc-impi/2018.4
   module load python/3.7.5
   module load hdf5/1.10.6-parallel
   module load wgrib/1.8.0b
   export PYTHONPATH=/home/jwhitake/.local/lib/python3.7/site-packages
   export HDF5_DISABLE_VERSION_CHECK=1
   export WGRIB=`which wgrib`
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f2/dev/${USER}
   export datadir=/lustre/f2/scratch/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   #export hsidir="/3year/NCEPDEV/GEFSRR/${exptname}"
   export obs_datapath=/lustre/f2/dev/Jeffrey.S.Whitaker/dumps
else
   echo "machine must be 'hera', 'orion' or 'gaea' got $machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"

export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
export NOTLNMC="NO" # no TLNMC in GSI in GSI EnVar
export NOOUTERLOOP="NO" # no outer loop in GSI EnVar
# model NSST parameters contained within nstf_name in FV3 namelist
# (comment out to get default - no NSST)
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
export DONST="YES"
export NST_MODEL=2
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
export NST_SPINUP=0 # (will be set to 1 if cold_start=='true')
# nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
export NST_RESV=0
# nstf_name(4,5) : ZSEA1, ZSEA2 the two depths to apply vertical average (bias correction)
export ZSEA1=0
export ZSEA2=0
export NSTINFO=0          # number of elements added in obs. data array (default = 0)
export NST_GSI=3          # default 0: No NST info at all;
                          #         1: Input NST info but not used in GSI;
                          #         2: Input NST info, used in CRTM simulation, no Tr analysis
                          #         3: Input NST info, used in both CRTM simulation and Tr analysis

# turn off NST
export DONST="NO"
export NST_MODEL=0
export NST_GSI=0

if [ $NST_GSI -gt 0 ]; then export NSTINFO=4; fi
if [ $NOSAT == "YES" ]; then export NST_GSI=0; fi # don't try to do NST in GSI without satellite data

export LEVS=127
export aircraft_t_bc=.true.
export aircraft_t_bc=.true.
if [ $LEVS -eq 64 ]; then
  export nsig_ext=12
  export gpstop=50
  export GRIDOPTS="nlayers(63)=3,nlayers(64)=6,"
  if [ $DONST == "YES" ]; then
     export SUITE="FV3_GFS_v15p2"
  else
     export SUITE="FV3_GFS_v15p2_no_nsst"
  fi
elif [ $LEVS -eq 127 ]; then
  export nsig_ext=56
  export gpstop=55
  export GRIDOPTS="nlayers(63)=1,nlayers(64)=1,"
  if [ $DONST == "YES" ]; then
     export SUITE="FV3_GFS_v16"
  else
     export SUITE="FV3_GFS_v16_no_nsst"
  fi
else
  echo "LEVS must be 64 or 127"
  exit 1
fi

# radiance thinning parameters for GSI
export dmesh1=145
export dmesh2=145
export dmesh3=100

#export use_ipd="YES" # use IPD instead of CCPP

# stochastic physics parameters.
export DO_SPPT=T
export SPPT=0.5
export DO_SHUM=T
export SHUM=0.005
export DO_SKEB=T
export SKEB=0.3
# turn off stochastic physics
#export SKEB=0
#export DO_SKEB=F
#export SPPT=0
#export DO_SPPT=F
#export SHUM=0
#export DO_SHUM=F

export imp_physics=11 # used by GSI, not model

# resolution dependent model parameters
if [ $RES -eq 384 ]; then
   export JCAP=766
   export LONB=1536
   export LATB=768
   export dt_atmos=225 # for n_split=6
   export cdmbgwd="1.1,0.72,1.0,1.0"
elif [ $RES -eq 192 ]; then
   export JCAP=382 
   export LONB=768   
   export LATB=384  
   export dt_atmos=450
   export cdmbgwd="0.23,1.5,1.0,1.0"
elif [ $RES -eq 128 ]; then
   export JCAP=254 
   export LONB=512   
   export LATB=256  
   export dt_atmos=720
   export cdmbgwd="0.19,1.6,1.0,1.0"  
elif [ $RES -eq 96 ]; then
   export JCAP=188
   export LONB=384   
   export LATB=192
   export dt_atmos=900
   export cdmbgwd="0.14,1.8,1.0,1.0"  # mountain blocking, ogwd, cgwd, cgwd src scaling
elif [ $RES -eq 48 ]; then
   export JCAP=94
   export LONB=192   
   export LATB=96   
   export dt_atmos=1800
   export cdmbgwd="0.071,2.1,1.0,1.0"  
else
   echo "model parameters for ensemble resolution C$RES not set"
   exit 1
fi

if [ $RES_CTL -eq 768 ]; then
   export cdmbgwd_ctl="4.0,0.15,1.0,1.0"
   export JCAP_CTL=1534
   export LONB_CTL=3072
   export LATB_CTL=1536
   export dt_atmos_ctl=150    
elif [ $RES_CTL -eq 384 ]; then
   export dt_atmos_ctl=225
   export cdmbgwd_ctl="1.1,0.72,1.0,1.0"
   export JCAP_CTL=766
   export LONB_CTL=1536
   export LATB_CTL=768
elif [ $RES_CTL -eq 192 ]; then
   export dt_atmos_ctl=450
   export cdmbgwd_ctl="0.23,1.5,1.0,1.0"
   export JCAP_CTL=382
   export LONB_CTL=768  
   export LATB_CTL=384
elif [ $RES_CTL -eq 96 ]; then
   export dt_atmos_ctl=900
   export cdmbgwd="0.14,1.8,1.0,1.0"  # mountain blocking, ogwd, cgwd, cgwd src scaling
   export JCAP_CTL=188
   export LONB_CTL=384  
   export LATB_CTL=192
else
   echo "model parameters for control resolution C$RES_CTL not set"
   exit 1
fi
export FHCYC=0 # run global_cycle instead of gcycle inside model

# analysis is done at ensemble resolution
export LONA=$LONB
export LATA=$LATB      

export ANALINC=6

export FHMIN=3
export FHMAX=9
export FHOUT=1
export RESTART_FREQ=3
FHMAXP1=`expr $FHMAX + 1`
# if FHMAX_LONGER divisible by 6, only the last output time saved.
# if not divisible by 6, all times in 6-h window at the end of forecast saved
# so GSI observer can be run.
export FHMAX_LONGER=12
export enkfstatefhrs=`python -c "from __future__ import print_function; print(list(range(${FHMIN},${FHMAXP1},${FHOUT})))" | cut -f2 -d"[" | cut -f1 -d"]"`
export iaufhrs="3,6,9"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off
# IAU off
#export iaufhrs="6"
#export iau_delthrs=-1

# other model variables set in ${rungfs}
# other gsi variables set in ${rungsi}

export RUN=gdas # use gdas or gfs obs

# Analysis increments to zero out
export INCREMENTS_TO_ZERO="'liq_wat_inc','icmr_inc'"
# Stratospheric increments to zero
export INCVARS_ZERO_STRAT="'sphum_inc','liq_wat_inc','icmr_inc'"
export INCVARS_EFOLD="5"
export write_fv3_increment=".false." # don't change this
export WRITE_INCR_ZERO="incvars_to_zero= $INCREMENTS_TO_ZERO,"
export WRITE_ZERO_STRAT="incvars_zero_strat= $INCVARS_ZERO_STRAT,"
export WRITE_STRAT_EFOLD="incvars_efold= $INCVARS_EFOLD,"
export use_correlated_oberrs=".true."
# NOTE: most other GSI namelist variables are in ${rungsi}

export SMOOTHINF=35 # inflation smoothing (spectral truncation)
export covinflatemax=1.e2
export reducedgrid=.false. # if T, used reduced gaussian analysis grid in EnKF
export covinflatemin=1.0                                            
export analpertwtnh=0.85
export analpertwtsh=0.85
export analpertwttr=0.85
export analpertwtnh_rtpp=0.0
export analpertwtsh_rtpp=0.0
export analpertwttr_rtpp=0.0
export pseudo_rh=.true.
export write_ensmean=.true. # write out ens mean analysis in EnKF
if [[ $write_ensmean == ".true." ]]; then
   export ENKFVARS="write_ensmean=${write_ensmean},"
fi
export letkf_flag=.true.
export letkf_bruteforce_search=.false.
export denkf=.true.
export getkf=.true.
export getkf_inflation=.false.
export modelspace_vloc=.true.
export letkf_novlocal=.true.
export nobsl_max=10000
export corrlengthnh=1250
export corrlengthtr=1250
export corrlengthsh=1250
# The lnsigcutoff* parameters are ignored if modelspace_vloc=T
export lnsigcutoffnh=1.5
export lnsigcutofftr=1.5
export lnsigcutoffsh=1.5
export lnsigcutoffpsnh=1.5
export lnsigcutoffpstr=1.5
export lnsigcutoffpssh=1.5
export lnsigcutoffsatnh=1.5 
export lnsigcutoffsattr=1.5  
export lnsigcutoffsatsh=1.5  
export paoverpb_thresh=0.998  # ignored for LETKF, set to 1 to use all obs in serial EnKF
export saterrfact=1.0
export deterministic=.true.
export sortinc=.true.

# these only used for hybrid covariance (hyb 4denvar) in GSI
export beta_s0=`python -c "from __future__ import print_function; print($alpha / 1000.)"` # weight given to static B in hyb cov
# beta_e0 parameter (ensemble weight) in my GSI branch (not in GSI/develop)
export beta_e0=`python -c "from __future__ import print_function; print($beta / 1000.)"` # weight given to ensemble B in hyb cov
export s_ens_h=343.     # 1250 km horiz localization in GSI
#export s_ens_v=-0.58    # 1.5 scale heights in GSI
if [ $LEVS -eq 64 ]; then
  export s_ens_v=5.4 # 14 levels
elif [ $LEVS -eq 127 ]; then
  export s_ens_v=7.7 # 20 levels
fi
# use pre-generated bias files.
#export biascorrdir=${datadir}/biascor

export nanals=80                                                    
# if nanals2>0, extend nanals2 members out to FHMAX + ANALINC (one extra assim window)
#export nanals2=-1 # longer extension. Set to -1 to disable 
#export nanals2=$NODES
export nanals2=$nanals
export nitermax=1 # number of retries
export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"

if [ "$machine" == 'hera' ]; then
   export python=/contrib/anaconda/2.3.0/bin/python
   export fv3gfspath=/scratch1/NCEPDEV/global/glopara
   export FIXFV3=${fv3gfspath}/fix_NEW/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix_NEW/fix_am
   export FIXgsm=$FIXGLOBAL # for global_cycle
   export gsipath=/scratch2/BMC/gsienkf/Jeffrey.S.Whitaker/gsi/GSI-github-jswhit-master
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
elif [ "$machine" == 'orion' ]; then
   export python=`which python`
   export fv3gfspath=/work/noaa/global/glopara
   export FIXFV3=$fv3gfspath/fix_NEW/fix_fv3_gmted2010
   export FIXGLOBAL=$fv3gfspath/fix_NEW/fix_am
   export gsipath=/work/noaa/gsienkf/whitaker/GSI-enkf64bit
   export fixgsi=${gsipath}/fix
   export fixcrtm=$fv3gfspath/crtm/crtm_v2.3.0
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
elif [ "$machine" == 'gaea' ]; then
   export python=/ncrc/sw/gaea/PythonEnv-noaa/1.4.0/.spack/opt/spack/linux-sles12-x86_64/gcc-4.8/python-2.7.14-zyx34h36bfp2c6ftp5bhdsdduqjxbvp6/bin/python
   #export PYTHONPATH=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/lib/python2.7/site-packages
   #export fv3gfspath=/lustre/f1/pdata/ncep_shared/fv3/fix-fv3gfs/
   export fv3gfspath=/lustre/f2/dev/Jeffrey.S.Whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=/lustre/f2/dev/Jeffrey.S.Whitaker/GSI-github-jswhit
   export fixgsi=${gsipath}/fix
   export fixcrtm=/lustre/f2/pdata/ncep_shared/NCEPLIBS/lib/crtm/v2.2.6/fix
   #export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
else
   echo "${machine} unsupported machine"
   exit 1
fi
# set to .true. to run hydrostatic version of model 
export hydrostatic=.false.
if [ $hydrostatic == ".true." ]; then
   export FCSTEXEC=${execdir}/fv3-hydro.exe
else
   export FCSTEXEC=${execdir}/fv3-nonhydro.exe
fi


export ANAVINFO=${fixgsi}/global_anavinfo.l${LEVS}.txt
export ANAVINFO_ENKF=${ANAVINFO}
export HYBENSINFO=${fixgsi}/global_hybens_info.l${LEVS}.txt # only used if readin_beta or readin_localization=T
#export HYBENSINFO=${enkfscripts}/global_hybens_info.l${LEVS}.txt # only used if readin_beta or readin_localization=T
# comment out next line to disable smoothing of ensemble perturbations
# in stratosphere/mesosphere
#export HYBENSMOOTHINFO=${fixgsi}/global_hybens_smoothinfo.l${LEVS}.txt
export OZINFO=${fixgsi}/global_ozinfo.txt
export CONVINFO=${fixgsi}/global_convinfo.txt
export SATINFO=${fixgsi}/global_satinfo.txt
export NLAT=$((${LATA}+2))
# default is to use berror file in gsi fix dir.
#export BERROR=${basedir}/staticB/global_berror_enkf.l${LEVS}y${NLAT}.f77
#export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_janjulysmooth0p5
#export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_annmeansmooth0p5
export REALTIME=NO # if NO, use historical files set in main.sh

cd $enkfscripts
echo "run main driver script"
if [ $controlanal == "true" ]; then
   # run as in NCEP ops, with high-res control forecast updated by GSI hyb 4denvar,
   # and enkf analysis recentered around upscaled control analysis.
   # use static B weights and localization scales for GSI from files.
   # (s_ens_h, s_ens_v, beta_s0, beta_e0 will be ignored)
   export readin_localization=".true."
   export readin_beta=".true."
   export replay_controlfcst=".false."
   export hybgain=".false." # controlanal takes precedence over hybgain
   export HYBENSINFO=${fixgsi}/global_hybens_info.l${LEVS}.txt # only used if readin_beta or readin_localization=T
   # uncomment to smooth ensemble perturbations
   #export HYBENSMOOTHINFO=${fixgsi}/global_hybens_smoothinfo.l${LEVS}.txt
   sh ./main_controlanal.sh
else
   # GSI sees ensemble mean background (high-res control forecast is a replay to ens mean analysis)
   # (s_ens_h, s_ens_v, beta_s0, beta_e0, alpha, beta used)
   if [ $hybgain == "false" ]; then
      # use static B weights and localization scales for GSI from files.
      # (beta_s0, beta_e0 ignored)
      export readin_localization=".true."
      export readin_beta=".true."
      # use constant values (beta_s0,beta_e0 parameters)
      #export readin_beta=.false.
      #export readin_localization=.false.
      # these only used for hybrid covariance (hyb 4denvar) in GSI
      export beta_s0=`python -c "from __future__ import print_function; print($alpha / 1000.)"` # weight given to static B in hyb cov
      # beta_e0 parameter (ensemble weight) in my GSI branch (not in GSI/develop)
      export beta_e0=`python -c "from __future__ import print_function; print($beta / 1000.)"` # weight given to ensemble B in hyb cov
   else
      export beta_s0=1.000 # 3dvar
      export beta_e0=0.0
      export readin_beta=.false.
      export readin_localization=.false.
   fi
   sh ./main.sh
fi
