echo "running on $machine using $NODES nodes"
## ulimit -s unlimited

# resolution of control and ensmemble.
export RES=192
export RES_CTL=384 
# Penney 2014 Hybrid Gain algorithm with beta_1=1.0
# beta_2=alpha and beta_3=0 in eqn 6 
# (https://journals.ametsoc.org/doi/10.1175/MWR-D-13-00131.1)
export alpha=500 # percentage of 3dvar increment (beta_2*1000)
export hybgain='true' # set to true for hybrid gain 3DVar/EnKF
export exptname="C${RES}C${RES_CTL}_hybgain"
export cores=`expr $NODES \* $corespernode`

# check that value of NODES is consistent with PBS_NP on theia.
if [ "$machine" == 'theia' ]; then
   if [ $PBS_NP -ne $cores ]; then
     echo "NODES = ${NODES} PBS_NP = ${PBS_NP} cores = ${cores}"
     echo "NODES set incorrectly in preamble"
     exit 1
   fi
fi
#export KMP_AFFINITY=disabled

export fg_gfs="run_ens_fv3.csh"
export ensda="enkf_run.csh"
export rungsi='run_gsi_4densvar.sh'
export rungfs='run_fv3.sh' # ensemble forecast

export recenter_anal="true" # recenter enkf analysis around GSI hybrid 4DEnVar analysis
export do_cleanup='true' # if true, create tar files, delete *mem* files.
export controlanal='true' # use gsi hybrid (if false, pure enkf is used)
export controlfcst='true' # if true, run dual-res setup with single high-res control
export cleanup_fg='true'
export cleanup_ensmean='true'
export cleanup_anal='true'
export cleanup_controlanl='true'
export cleanup_observer='true' 
export resubmit='true'
# for 'passive' or 'replay' cycling of control fcst 
# control forecast files have 'control2' suffix, instead of 'control'
# GSI observer will be run on 'control2' forecast
# this is for diagnostic purposes (to get GSI diagnostic files) 
export replay_controlfcst='true'
export replay_run_observer='true' # run observer on replay forecast
# python script checkdate.py used to check
# YYYYMMDDHH analysis date string to see if
# full ensemble should be saved to HPSS (returns 0 if 
# HPSS save should be done)
export save_hpss_subset="true" # save a subset of data each analysis time to HPSS
export save_hpss="true"
export run_long_fcst="false"  # spawn a longer control forecast at 00 UTC
export ensmean_restart='false'
#export copy_history_files=1 # save pressure level history files (and compute ens mean)

# override values from above for debugging.
#export cleanup_ensmean='false'
#export cleanup_observer='false'
#export cleanup_anal='false'
#export cleanup_controlanl='false'
#export recenter_anal="false"
#export cleanup_fg='false'
#export resubmit='false'
#export do_cleanup='false'
#export save_hpss_subset="false" # save a subset of data each analysis time to HPSS
 
if [ "$machine" == 'wcoss' ]; then
   export basedir=/gpfs/hps2/esrl/gefsrr/noscrub/${USER}
   export datadir=/gpfs/hps2/ptmp/${USER}
   export hsidir="/3year/NCEPDEV/GEFSRR/${USER}/${exptname}"
   export obs_datapath=${basedir}/gdas1bufr
elif [ "$machine" == 'theia' ]; then
   export basedir=/scratch3/BMC/gsienkf/${USER}
   export datadir=$basedir
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   export obs_datapath=/scratch3/BMC/gsienkf/whitaker/gdas1bufr
elif [ "$machine" == 'gaea' ]; then
   export basedir=/lustre/f1/unswept/${USER}/fv3_reanl
   export datadir=/lustre/f1/${USER}
   export hsidir="/ESRL/BMC/gsienkf/2year/whitaker/${exptname}"
   #export hsidir="/3year/NCEPDEV/GEFSRR/${exptname}"
   export obs_datapath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/gdas1bufr
elif [ "$machine" == 'cori' ]; then
   export basedir=${SCRATCH}
   export datadir=$basedir
   export hsidir="fv3_reanl/${exptname}"
   export obs_datapath=${basedir}/gdas1bufr
else
   echo "machine must be 'wcoss', 'theia', 'gaea' or 'cori', got $machine"
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
export lnsigcutoffpsnh=1.5
export lnsigcutoffpstr=1.5
export lnsigcutoffpssh=1.5
export lnsigcutoffsatnh=1.5 
export lnsigcutoffsattr=1.5  
export lnsigcutoffsatsh=1.5  
export obtimelnh=1.e30       
export obtimeltr=1.e30       
export obtimelsh=1.e30       
export readin_localization=.true.

# model physics parameters.
export psautco="0.0008,0.0005"
export prautco="0.00015,0.00015"
#export imp_physics=99 # zhao-carr
export imp_physics=11 # GFDL MP

export NOSAT="NO" # if yes, no radiances assimilated
export NOCONV="NO"
# model NSST parameters contained within nstf_name in FV3 namelist
# (comment out to get default - no NSST)
# nstf_name(1) : NST_MODEL (NSST Model) : 0 = OFF, 1 = ON but uncoupled, 2 = ON and coupled
#export DONST="YES"
#export NST_MODEL=2
## nstf_name(2) : NST_SPINUP : 0 = OFF, 1 = ON,
#export NST_SPINUP=0 # (will be set to 1 if fg_only=='true')
## nstf_name(3) : NST_RESV (Reserved, NSST Analysis) : 0 = OFF, 1 = ON
#export NST_RESV=0
## nstf_name(4,5) : ZSEA1, ZSEA2 the two depths to apply vertical average (bias correction)
#export ZSEA1=0
#export ZSEA2=0
#export NSTINFO=0          # number of elements added in obs. data array (default = 0)
#export NST_GSI=3          # default 0: No NST info at all;
                          #         1: Input NST info but not used in GSI;
                          #         2: Input NST info, used in CRTM simulation, no Tr analysis
                          #         3: Input NST info, used in both CRTM simulation and Tr analysis

export NST_GSI=0          # No NST 

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
else
   export ncld=1
   export nwat=2
   export cal_pre=T
   export dnats=0
fi
export k_split=1
export n_split=6
export fv_sg_adj=450
export fv_sg_adj_ctl=$fv_sg_adj
export hydrostatic=F
if [ $hydrostatic == 'T' ];  then
   export fv3exec='fv3-hydro.exe'
   export consv_te=0
else
   export fv3exec='fv3-nonhydro.exe'
   export consv_te=1
fi
# defaults in exglobal_fcst
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
# GFDL suggests this for imp_physics=11
if [ $imp_physics -eq 11 ]; then 
   export hord_mt=6
   export hord_vt=6
   export hord_tm=6
   export hord_dp=-6
   export nord=2
   export dddmp=0.1
   export d4_bg=0.12
   export vtdm4=0.02
fi

# stochastic physics parameters.
export SPPT=0.5
export SPPT_TSCALE=21600.
export SPPT_LSCALE=500.e3
export SHUM=0.005
export SHUM_TSCALE=21600.
export SHUM_LSCALE=500.e3
export SKEB=0.3
export SKEB_TSCALE=21600.
export SKEB_LSCALE=500.e3
export SKEBNORM=0
export SKEB_NPASS=30
export SKEB_VDOF=5

# resolution dependent model parameters
if [ $RES -eq 384 ]; then
   export JCAP=766
   export LONB=1536
   export LATB=768
   export dt_atmos=225 # for n_split=6
   export cdmbgwd="1.0,1.2"
elif [ $RES -eq 192 ]; then
   export JCAP=382 
   export LONB=768   
   export LATB=384  
   export dt_atmos=450
   export cdmbgwd="0.2,2.5"
elif [ $RES -eq 128 ]; then
   export JCAP=254 
   export LONB=512   
   export LATB=256  
   export dt_atmos=720
   export cdmbgwd="0.15,2.75"
elif [ $RES -eq 96 ]; then
   export JCAP=188 
   export LONB=384   
   export LATB=190  
   export dt_atmos=900
   export cdmbgwd="0.125,3.0"
else
   echo "model parameters for ensemble resolution C$RES_CTL not set"
   exit 1
fi

if [ $RES_CTL -eq 768 ]; then
   export cdmbgwd_ctl="3.5,0.25"
   export LONB_CTL=3072
   export LATB_CTL=1536
   export k_split_ctl=2
   export n_split_ctl=6
   export dt_atmos_ctl=225
   #export dt_atmos_ctl=112.5
elif [ $RES_CTL -eq 384 ]; then
   export dt_atmos_ctl=225
   export cdmbgwd_ctl="1.0,1.2"
   export LONB_CTL=1536
   export LATB_CTL=768
elif [ $RES_CTL -eq 192 ]; then
   export dt_atmos_ctl=450
   export cdmbgwd_ctl="0.25,2.0"
   export LONB_CTL=768  
   export LATB_CTL=384
elif [ $RES_CTL -eq 96 ]; then
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
export RUN=gdas1 # use gdas obs
export reducedgrid=.true.
export univaroz=.false.

export iassim_order=0

export covinflatemax=1.e2
export covinflatemin=1.0                                            
export analpertwtnh=0.75
export analpertwtsh=0.75
export analpertwttr=0.75
export analpertwtnh_rtpp=0.0
export analpertwtsh_rtpp=0.0
export analpertwttr_rtpp=0.0
export pseudo_rh=.true.
                                                                    
export letkf_flag=.true.
export denkf=.true.
export getkf=.true.
export getkf_inflation=.false.
export modelspace_vloc=.true.
export letkf_novlocal=.true.
export dfs_sort=.false.
export nobsl_max=10000
export sprd_tol=1.e30
export varqc=.false.
export huber=.false.
export zhuberleft=1.e10
export zhuberright=1.e10

export biasvar=-500
if [ $controlanal == 'false' ] && [ $NOSAT == "NO" ];  then
   export lupd_satbiasc=.true.
   export numiter=4
else
   export lupd_satbiasc=.false.
   export numiter=0
fi
# iterate enkf in obspace for varqc
if [ $varqc == ".true." ]; then
  export numiter=5
fi
# use pre-generated bias files.
#export lupd_satbiasc=.false.
#export numiter=0
#export biascorrdir=${datadir}/C192C192_skeb2


# turn on enkf analog of VarQC
#export sprd_tol=10.
#export varqc=.true.
#export huber=.true.
#export zhuberleft=1.1
#export zhuberright=1.1
                                                                    
export nanals=80                                                    
                                                                    
export paoverpb_thresh=0.998  # set to 1.0 to use all the obs in serial EnKF
export saterrfact=1.0
export deterministic=.true.
export sortinc=.true.
                                                                    
export nitermax=1

export enkfscripts="${basedir}/scripts/${exptname}"
export homedir=$enkfscripts
export incdate="${enkfscripts}/incdate.sh"

if [ "$machine" == 'theia' ]; then
   export fv3gfspath=/scratch4/NCEPDEV/global/save/glopara/svn/fv3gfs
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=/scratch3/BMC/gsienkf/whitaker/gsi/ProdGSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=/scratch3/BMC/gsienkf/whitaker/gsi/branches/EXP-enkflinhx/fix/crtm_2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'gaea' ]; then
   #export fv3gfspath=/lustre/f1/pdata/ncep_shared/fv3/fix-fv3gfs/
   export fv3gfspath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export gsipath=/lustre/f1/unswept/Jeffrey.S.Whitaker/fv3_reanl/ProdGSI
   export fixgsi=${gsipath}/fix
   export fixcrtm=/lustre/f1/pdata/ncep_shared/NCEPLIBS/lib/crtm/v2.2.5/fix
   #export fixcrtm=${fixgsi}/crtm_v2.2.3
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
   export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
elif [ "$machine" == 'cori' ]; then
   #export fv3gfspath=/project/projectdirs/refcst/whitaker/fv3_reanl/fv3gfs/global_shared.v15.0.0
   export fv3gfspath=$SCRATCH/global_shared.v15.0.0
   #export gsipath=/project/projectdirs/refcst/whitaker/fv3_reanl/ProdGSI
   export gsipath=$SCRATCH/ProdGSI
   export FIXFV3=${fv3gfspath}/fix/fix_fv3_gmted2010
   export FIXGLOBAL=${fv3gfspath}/fix/fix_am
   export fixgsi=${gsipath}/fix
   export fixcrtm=${fixgsi}/crtm_v2.2.3
   export execdir=${enkfscripts}/exec_${machine}
   export enkfbin=${execdir}/global_enkf
   export FCSTEXEC=${execdir}/${fv3exec}
   export gsiexec=${execdir}/global_gsi
   export nemsioget=${execdir}/nemsio_get
else
   echo "${machine} unsupported machine"
   exit 1
fi

#export ANAVINFO=${enkfscripts}/global_anavinfo.l64.txt.clrsky
export ANAVINFO=${enkfscripts}/global_anavinfo.l64.txt
export ANAVINFO_ENKF=${ANAVINFO}
export HYBENSINFO=${enkfscripts}/global_hybens_info.l64.txt
export CONVINFO=${enkfscripts}/global_convinfo_oper_fix.txt
export OZINFO=${enkfscripts}/global_ozinfo_oper_fix.txt
#export SATINFO=${enkfscripts}/global_satinfo.txt.clrsky
export SATINFO=${enkfscripts}/global_satinfo.txt

# parameters for hybrid gain
if [ $hybgain == "true" ]; then
   export beta1_inv=1.000
else
   export beta1_inv=0.125   # 0 means all ensemble, 1 means all 3DVar.
fi
export beta=1000 # percentage of enkf increment (*10)

# NOTE: most other GSI namelist variables are in ${rungsi}
export aircraft_bc=.true.
export use_prepb_satwnd=.false.

cd $enkfscripts
echo "run main driver script"
csh main.csh
