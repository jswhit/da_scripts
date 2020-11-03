# hybrid gain GSI(3DVar)/EnKF workflow
export cores=`expr $NODES \* $corespernode`
echo "running on $machine using $NODES nodes and $cores CORES"

export ndates_job=1 # number of DA cycles to run in one job submission
# resolution of control and ensmemble.
export RES=384 
export RES_CTL=768 
# Penney 2014 Hybrid Gain algorithm with beta_1=1.0
# beta_2=alpha and beta_3=0 in eqn 6 
# (https://journals.ametsoc.org/doi/10.1175/MWR-D-13-00131.1)
export alpha=250 # percentage of 3dvar increment (beta_2*1000)
export beta=1000 # percentage of enkf increment (*10)
export exptname="C${RES}_hybgain"
# for 'passive' or 'replay' cycling of control fcst 
export replay_controlfcst='true'

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
export replay_run_observer='true' # run observer on replay control forecast
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
export run_long_fcst="false"  # spawn a longer control forecast at 00 UTC
export ensmean_restart='false'
export skip_to_fcst="false" # skip to forecast step

# override values from above for debugging.
#export cleanup_ensmean='false'
#export cleanup_observer='false'
#export cleanup_controlanl='false'
#export cleanup_anal='false'
#export recenter_anal="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
#export save_hpss_subset="false" # save a subset of data each analysis time to HPSS
#export skip_to_fcst="true" # skip to forecast step
 
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
   #export obs_datapath=/scratch2/BMC/gsienkf/whitaker/gdas1bufr
   export obs_datapath=${basedir}/dumps
   ulimit -s unlimited
   source $MODULESHOME/init/sh
   module purge
   module load intel/2018.4
   module load impi/2018.4
   module load mkl/2018.4
   export NCEPLIBS=/apps/contrib/NCEPLIBS/lib
   module use -a $NCEPLIBS/modulefiles
   module unload netcdf/4.7.4 
   module unload hdf5/1.10.6
   module load netcdfp/4.7.4
   export PYTHONPATH=/home/jwhitake/.local/lib/python3.7/site-packages
   export HDF5_DISABLE_VERSION_CHECK=1
   module list
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
export corrlengthnh=1250
export corrlengthtr=1250
export corrlengthsh=1250
export lnsigcutoffnh=1.5
export lnsigcutofftr=1.5
export lnsigcutoffsh=1.5
export lnsigcutoffpsnh=1.5
export lnsigcutoffpstr=1.5
export lnsigcutoffpssh=1.5
export lnsigcutoffsatnh=1.5 
export lnsigcutoffsattr=1.5  
export lnsigcutoffsatsh=1.5  
export obtimelnh=1.e30       
export obtimeltr=1.e30       
export obtimelsh=1.e30       

# model physics parameters.
export LEVS=127 # 127 for gfsv16, 64 for gfsv15
export psautco="0.0008,0.0005"
export prautco="0.00015,0.00015"
#export imp_physics=99 # zhao-carr
export imp_physics=11 # GFDL MP

export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
# model NSST parameters contained within nstf_name in FV3 namelist
# (comment out to get default - no NSST)
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
export DONST="YES"
export NST_MODEL=2
# nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
export NST_SPINUP=0 # (will be set to 1 if fg_only=='true')
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

#export NST_GSI=0          # No NST 

if [ $NST_GSI -gt 0 ]; then export NSTINFO=4; fi
if [ $NOSAT == "YES" ]; then export NST_GSI=0; fi # don't try to do NST in GSI without satellite data

if [ $imp_physics == "11" ]; then
   export ncld=5
   export nwat=6
   export cal_pre=F
   export dnats=1
   export do_sat_adj=".true."
   export random_clds=".false."
   export cnvcld=".false."
   export lgfdlmprad=".true."
   export effr_in=".true."
else
   export ncld=1
   export nwat=2
   export cal_pre=T
   export dnats=0
fi
export fv3exec='fv3-nonhydro.exe'
export hord_mt=5
export hord_vt=5
export hord_tm=5
export hord_dp=-5
export consv_te=1
export dddmp=0.1
export d4_bg=0.12
export vtdm4=0.02
export fv_sg_adj=450
export nord=2

#gfsv15
if [ $LEVS -eq '64' ]; then
   export satmedmf=F
   export hybedmf=T
   export lheatstrg=F
   export IAER=111
   export iovr_lw=1
   export iovr_sw=1
   export icliq_sw=1
   export do_tofd=F
   export reiflag=1
   export adjust_dry_mass=F
   export vtdm4=0.06
   export tau=10.0
   export rf_cutoff=750.0
   export d2_bg_k1=0.15
   export d2_bg_k2=0.02
elif [ $LEVS -eq 127 ]; then
#gfsv16
   export satmedmf=T
   export hybedmf=F
   export lheatstrg=T
   export IAER=5111
   export iovr_lw=3
   export iovr_sw=3
   export icliq_sw=2
   export do_tofd=T
   export reiflag=2
   export adjust_dry_mass=T
   export tau=5.0
   export rf_cutoff=1.e3
   export d2_bg_k1=0.20 
   export d2_bg_k2=0.0
else
   echo "LEVS must be 64 or 127"
   exit 1
fi

# stochastic physics parameters.
export DO_SPPT=.true.
export SPPT=0.5
export SPPT_TSCALE=21600
export SPPT_LSCALE=500000
export DO_SHUM=.true.
export SHUM=0.005
export SHUM_TSCALE=21600
export SHUM_LSCALE=500000
export DO_SKEB=.true.
export SKEB=0.3
export SKEB_TSCALE=21600
export SKEB_LSCALE=250000
export SKEBINT=1800
export SKEBNORM=0
export SKEB_NPASS=30
export SKEB_VDOF=5

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
   export LATB=190  
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
   export k_split_ctl=2
   export n_split_ctl=6
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
export FHMAX_LONG=120 # control forecast every 00UTC in run_long_fcst=true
export FHOUT=3
FHMAXP1=`expr $FHMAX + 1`
export enkfstatefhrs=`python -c "from __future__ import print_function; print(list(range(${FHMIN},${FHMAXP1},${FHOUT})))" | cut -f2 -d"[" | cut -f1 -d"]"`

export iaufhrs="3,6,9"
export iau_delthrs="6" # iau_delthrs < 0 turns IAU off
# NO IAU.
#export iaufhrs="6"
#export iau_delthrs=-1

# other model variables set in ${rungfs}
# other gsi variables set in ${rungsi}

export SMOOTHINF=35
export npts=`expr \( $LONA \) \* \( $LATA \)`
export RUN=gdas # use gdas obs
export reducedgrid=.false.
export univaroz=.false.

export iassim_order=0

export covinflatemax=1.e2
export covinflatemin=1.0                                            
export analpertwtnh=0.85
export analpertwtsh=0.85
export analpertwttr=0.85
export analpertwtnh_rtpp=0.0
export analpertwtsh_rtpp=0.0
export analpertwttr_rtpp=0.0
export pseudo_rh=.true.
export use_correlated_oberrs=".true."
                                                                    
# Analysis increments to zero out
export INCREMENTS_TO_ZERO="'liq_wat_inc','icmr_inc'"
# Stratospheric increments to zero
export INCVARS_ZERO_STRAT="'sphum_inc','liq_wat_inc','icmr_inc'"
export INCVARS_EFOLD="5"
export write_fv3_increment=".false."
export WRITE_INCR_ZERO="incvars_to_zero= $INCREMENTS_TO_ZERO,"
export WRITE_ZERO_STRAT="incvars_zero_strat= $INCVARS_ZERO_STRAT,"
export WRITE_STRAT_EFOLD="incvars_efold= $INCVARS_EFOLD,"
# NOTE: most other GSI namelist variables are in ${rungsi}
export aircraft_bc=.true.
export use_prepb_satwnd=.false.
export write_ensmean=.true. # write out ens mean analysis in EnKF
export letkf_flag=.true.
export letkf_bruteforce_search=.false.
export denkf=.false.
export getkf=.true.
export getkf_inflation=.false.
export modelspace_vloc=.true.
export letkf_novlocal=.true.
export nobsl_max=10000
export sprd_tol=1.e30
export varqc=.false.
export huber=.false.
export zhuberleft=1.e10
export zhuberright=1.e10

export lupd_satbiasc=.false.
export numiter=0
# use pre-generated bias files.
#export biascorrdir=${datadir}/C192C192_skeb2

export nanals=80                                                    
                                                                    
export paoverpb_thresh=0.998  # set to 1.0 to use all the obs in serial EnKF
export saterrfact=1.0
export deterministic=.true.
export sortinc=.true.
                                                                    
export nitermax=2

export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"

if [ "$machine" == 'hera' ]; then
   export python=/contrib/anaconda/2.3.0/bin/python
   export fv3gfspath=/scratch1/NCEPDEV/global/glopara
   export FIXFV3=${fv3gfspath}/fix_nco_gfsv16/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix_nco_gfsv16/fix_am
   export gsipath=/scratch1/NCEPDEV/global/glopara/git/global-workflow/gfsv16b/sorc/gsi.fd
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch2/NCEPDEV/nwprod/NCEPLIBS/fix/crtm_v2.3.0
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
elif [ "$machine" == 'orion' ]; then
   export python=`which python`
   export fv3gfspath=/work/noaa/global/glopara
   export FIXFV3=$fv3gfspath/fix_nco_gfsv16/fix_fv3_gmted2010
   export FIXGLOBAL=$fv3gfspath/fix_nco_gfsv16/fix_am
   export gsipath=${basedir}/ProdGSI
   export fixgsi=${gsipath}/fix
   #export fixcrtm=${basedir}/fix/crtm/v2.2.6/fix
   export fixcrtm=$fv3gfspath/crtm/crtm_v2.3.0
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
elif [ "$machine" == 'gaea' ]; then
   export python=/ncrc/sw/gaea/PythonEnv-noaa/1.4.0/.spack/opt/spack/linux-sles12-x86_64/gcc-4.8/python-2.7.14-zyx34h36bfp2c6ftp5bhdsdduqjxbvp6/bin/python
   #export PYTHONPATH=/ncrc/home2/Jeffrey.S.Whitaker/anaconda2/lib/python2.7/site-packages
   #export fv3gfspath=/lustre/f1/pdata/ncep_shared/fv3/fix-fv3gfs/
   export fv3gfspath=/lustre/f2/dev/Jeffrey.S.Whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=/lustre/f2/dev/Jeffrey.S.Whitaker/ProdGSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=/lustre/f2/pdata/ncep_shared/NCEPLIBS/lib/crtm/v2.2.5/fix
   #export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export CHGRESEXEC=${execdir}/enkf_chgres_recenter_nc.x
else
   echo "${machine} unsupported machine"
   exit 1
fi

export ANAVINFO=${fixgsi}/global_anavinfo.l${LEVS}.txt
export ANAVINFO_ENKF=${ANAVINFO}
export OZINFO=${fixgsi}/global_ozinfo.txt
export CONVINFO=${fixgsi}/global_convinfo.txt
export SATINFO=${fixgsi}/global_satinfo.txt
export NLAT=$((${LATA}+2))
# default is to use berror file in gsi fix dir.
export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_janjulysmooth0p5
#export BERROR=${basedir}/staticB/24h/global_berror.l${LEVS}y${NLAT}.f77_annmeansmooth0p5
export REALTIME=YES # if NO, use historical files set in main.sh

# parameters for hybrid gain
export beta1_inv=1.000 # 3dvar
export readin_beta=.false. # not relevant for 3dvar
export readin_localization=.false. # use fixed localization in EnKF.

cd $enkfscripts
echo "run main driver script"
sh ./main.sh
