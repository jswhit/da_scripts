# hybrid gain GSI(3DVar)/EnKF workflow
export cores=`expr $NODES \* $corespernode`
echo "running on $machine using $NODES nodes and $cores CORES"

export ndates_job=1 # number of DA cycles to run in one job submission
# resolution of control and ensmemble.
export RES=96   
export RES_CTL=$RES
export OCNRES="mx100"
export ORES3=`echo $OCNRES | cut -c3-5`
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
export exptname="C${RES}_3dvar_iau"
# for 'passive' or 'replay' cycling of control fcst 
export replay_controlfcst='false'

export fg_gfs="run_ens_fv3.sh"
export ensda="enkf_run.sh"
export rungsi='run_gsi_4densvar.sh'
export rungfs='run_fv3.sh' # ensemble forecast

export do_cleanup='true' # if true, create tar files, delete *mem* files.
export cleanup_fg='true'
export cleanup_anal='true'
export cleanup_controlanl='true'
export cleanup_observer='true' 
export resubmit='true'
# python script checkdate.py used to check
# YYYYMMDDHH analysis date string to see if
# full ensemble should be saved to HPSS (returns 0 if 
# HPSS save should be done)
if [ $machine == "orion" ] || [ $machine == "hercules" ]; then
   export save_hpss="false"
else
   export save_hpss="true"
fi
# override values from above for debugging.
#export cleanup_controlanl='false'
#export cleanup_observer='false'
#export cleanup_anal='false'
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
#export save_hpss="false" # save data each analysis time to HPSS

source $MODULESHOME/init/sh
if [ "$machine" == 'hera' ]; then
   export basedir=/scratch2/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/scratch1/NCEPDEV/global/glopara/dump
   module purge
   module load intel/18.0.5.274
   module load impi/2018.0.4 
   #module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   #module load netcdf_parallel/4.7.4
   #module load hdf5_parallel/1.10.6.release
   module use -a /scratch1/NCEPDEV/global/gwv/lp/lib/modulefiles
   module load netcdfp/4.7.4
   #module load esmflocal/8.0.1.08bs
   module use -a /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
   module load hdf5_parallel/1.10.6
   #module load netcdf_parallel/4.7.4
elif [ "$machine" == 'orion' ]; then
   export basedir=/work/noaa/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/work/noaa/sfc-perts/gbates/hrlyda_dumps/6hrly
   ulimit -s unlimited
   source $MODULESHOME/init/sh

   module purge
   #module load intel/2018.4
   #module load impi/2018.4
   #module load mkl/2018.4
   #export NCEPLIBS=/apps/contrib/NCEPLIBS/lib
   #module use -a $NCEPLIBS/modulefiles
   #module unload netcdf 
   #module unload hdf5
   #module load netcdfp/4.7.4


   module use /apps/contrib/NCEP/libs/hpc-stack/modulefiles/stack
   module load hpc/1.1.0
   module load hpc-intel/2018.4
   module unload mkl/2020.2
   module load mkl/2018.4
   module load hpc-impi/2018.4

   module load python/3.7.5
   export PYTHONPATH=/home/jwhitake/.local/lib/python3.7/site-packages
   export HDF5_DISABLE_VERSION_CHECK=1
   module list
elif [ $machine == "hercules" ]; then
   source $MODULESHOME/init/sh
   export basedir=/work2/noaa/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/work/noaa/rstprod/dump
   ulimit -s unlimited
   source $MODULESHOME/init/sh
   module use /work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-dev-20230717/envs/unified-env/install/modulefiles/Core
   #module use /work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
   module use /work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-dev-20230717/envs/unified-env/install/modulefiles/intel-oneapi-mpi/2021.9.0/intel/2021.9.0
   #module use /work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-1.5.0/envs/unified-env/install/modulefiles/intel-oneapi-mpi/2021.9.0/intel/2021.9.0
   module load stack-intel/2021.9.0
   module load stack-intel-oneapi-mpi/2021.9.0
   module load intel-oneapi-mkl/2022.2.1
   module load grib-util
   module load parallelio
   module load bufr/11.7.0
   module load crtm/2.4.0
   module load gsi-ncdiag
   export PATH="/work/noaa/gsienkf/whitaker/miniconda3/bin:$PATH"
   export HDF5_DISABLE_VERSION_CHECK=1
   export WGRIB=`which wgrib`
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f2/dev/${USER}
   export datadir=/lustre/f2/scratch/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   #export hsidir="/3year/NCEPDEV/GEFSRR/${exptname}"
   export obs_datapath=/lustre/f2/dev/Jeffrey.S.Whitaker/dumps
else
   echo "machine must be 'hera', 'orion', 'hercules' or 'gaea' got $machine"
   exit 1
fi
export datapath="${datadir}/${exptname}"
export logdir="${datadir}/logs/${exptname}"

export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
export NOTLNMC="NO" # no TLNMC in GSI in GSI EnVar
export NOOUTERLOOP="YES" # no outer loop in GSI EnVar
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
export NST_GSI=0          # default 0: No NST info at all;
                          #         1: Input NST info but not used in GSI;
                          #         2: Input NST info, used in CRTM simulation, no Tr analysis
                          #         3: Input NST info, used in both CRTM simulation and Tr analysis

if [ $NST_GSI -gt 0 ]; then export NSTINFO=4; fi
if [ $NOSAT == "YES" ]; then export NST_GSI=0; fi # don't try to do NST in GSI without satellite data

export LEVS=127  
export nsig_ext=56
export gpstop=55
export GRIDOPTS="nlayers(63)=1,nlayers(64)=1,"
export SUITE="FV3_GFS_v17_p8"

# radiance thinning parameters for GSI
export dmesh1=145
export dmesh2=145
export dmesh3=100

#export use_ipd="YES" # use IPD instead of CCPP

# turn off stochastic physics
export SKEB=0
export DO_SKEB=F
export SPPT=0
export DO_SPPT=F
export SHUM=0
export DO_SHUM=F

export imp_physics=8 # used by GSI, not model

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
   export dt_atmos_ctl=720
   export cdmbgwd_ctl="0.14,1.8,1.0,1.0"  # mountain blocking, ogwd, cgwd, cgwd src scaling
   export JCAP_CTL=188
   export LONB_CTL=384  
   export LATB_CTL=192
else
   echo "model parameters for control resolution C$RES_CTL not set"
   exit 1
fi

# analysis is done at ensemble resolution
export LONA=$LONB_CTL
export LATA=$LATB_CTL      

export ANALINC=6

export FHMIN=3
export FHMAX=9
export FHOUT=3
export FHCYC=6
export FRAC_GRID=T
export RESTART_FREQ=3
FHMAXP1=`expr $FHMAX + 1`
export FHMAX_LONGER=`expr $FHMAX + $ANALINC`
export enkfstatefhrs=`python -c "from __future__ import print_function; print(list(range(${FHMIN},${FHMAXP1},${FHOUT})))" | cut -f2 -d"[" | cut -f1 -d"]"`
export iaufhrs="6"
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

# use pre-generated bias files.
#export biascorrdir=${datadir}/biascor

export nitermax=1 # number of retries
export scriptsdir="${basedir}/scripts/${exptname}"
export homedir=$scriptsdir
export incdate="${scriptsdir}/incdate.sh"

if [ "$machine" == 'hera' ]; then
   export python=/contrib/anaconda/2.3.0/bin/python
   export fv3gfspath=/scratch1/NCEPDEV/global/glopara
   export FIXFV3=${fv3gfspath}/fix_nco_gfsv16/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix_nco_gfsv16/fix_am
   export gsipath=${basedir}/gsi/GSI-github-jswhit-master
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
   export execdir=${scriptsdir}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
elif [ "$machine" == 'orion' ] || [ $machine == "hercules" ]; then
   export python=`which python`
   export fv3gfspath=/work/noaa/global/glopara/fix_NEW
   export FIXDIR=/work/noaa/nems/emc.nemspara/RT/NEMSfv3gfs/input-data-20220414
   export FIXFV3=${fv3gfspath}/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix_am
   export gsipath=/work/noaa/gsienkf/whitaker/GSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=/work/noaa/global/glopara/crtm/crtm_v2.3.0
   if [ $machine == "hercules" ]; then
      export fixcrtm=$CRTM_FIX
   fi
   export execdir=${scriptsdir}/exec_${machine}
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
   export execdir=${scriptsdir}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
else
   echo "${machine} unsupported machine"
   exit 1
fi
export FCSTEXEC=${execdir}/fv3-nonhydro.exe


export no_mpinc=".false."
if [ $no_mpinc == ".false." ]; then
    export ANAVINFO=${fixgsi}/global_anavinfo_allhydro.l${LEVS}.txt
else
    export ANAVINFO=${fixgsi}/global_anavinfo.l${LEVS}.txt
fi
export NLAT=$((${LATA}+2))
# default is to use berror file in gsi fix dir.
#export BERROR=${basedir}/staticB/global_berror_enkf.l${LEVS}y${NLAT}.f77
#export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_janjulysmooth0p5
#export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_annmeansmooth0p5
export beta_s0=1
export beta_e0=0

cd $scriptsdir
echo "run main driver script"
sh ./main3dvar.sh
