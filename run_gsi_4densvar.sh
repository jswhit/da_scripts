#!/bin/sh
echo "Time starting at `date` "

VERBOSE=${VERBOSE:-"YES"}
if [[ "$VERBOSE" = "YES" ]]; then
   set -x
fi
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export OMP_STACKSIZE=${OMP_STACKSIZE:-256M}

# Set experiment name and analysis date
adate=${analdate:-2010081900}
adatem1=${analdatem1:-2010081900}
nens=${nanals:-80}

DONST=${DONST:-"NO"}
NST_GSI=${NST_GSI:-0}
NSTINFO=${NSTINFO:-0}
ZSEA1=${ZSEA1:-0}
ZSEA2=${ZSEA2:-0}
FAC_DTL=${FAC_DTL:-1}
FAC_TSL=${FAC_TSL:-1}
TZR_QC=${TZR_QC:-1}

HXONLY=${HXONLY:-"NO"}
HRLY_BKG=${HRLY_BKG:-"YES"}
NOSAT=${NOSAT:-"NO"}
skipcat=${skipcat:-"false"}

nprocs=${nprocs:-$PBS_NP}



# Set path/file for gsi executable
basedir=${HOMEGLOBAL}
gsipath=${gsipath:-${basedir}/gsi}
gsiexec=${gsiexec:-$gsipath/EXP-port/src/global_gsi}
charnanal=${charnanal:-'ensmean'}
# name just for diag files.
charnanal2=${charnanal2:-$charnanal}

# Given the analysis date, compute the date from which the
# first guess comes.  Extract cycle and set prefix and suffix
# for guess and observation data files
gdate=`${incdate} $adate -${ANALINC}`
hha=`echo $adate | cut -c9-10`
hham1=`echo $analdatem1 | cut -c9-10`
hhg=`echo $gdate | cut -c9-10`
yyyymmdda=`echo $adate | cut -c1-8`
RUN=${RUN:-gdas}
prefix_obs=${RUN}.t${hha}z
prefix_obsm1=${RUN}.t${hham1}z
prefix_tbc=${RUN}.t${hhg}z
suffix=tm00.bufr_d

datges=${datapath2:-/lfs1/projects/fim/whitaker/gfsenkf_test/$adate}
datgesm1=${datapathm1:-/lfs1/projects/fim/whitaker/gfsenkf_test/$gdate}
adate0=`echo $adate | cut -c1-8`
echo "adate = $adate"
iy=`echo $adate | cut -c1-4`
im=`echo $adate | cut -c5-6`
id=`echo $adate | cut -c7-8`
ih=`echo $adate | cut -c9-10`
echo "iy,im,id,ih = $iy $im $id $ih"
date_fhour=`python ${scriptsdir}/getidate.py ${datges}/bfg_${adate}_fhr03_${charnanal}`
fdatei=`echo $date_fhour | cut -f1 -d " "`
fhr=`echo $date_fhour | cut -f2 -d " "`
fdatev=`${incdate} $fdatei $fhr`
echo "fdatei=$fdatei fhr=$fhr fdatev=$fdatev"
gdate0=`echo $gdate | cut -c1-8`
obs_datapath=${obs_datapath:-/scratch1/NCEPDEV/global/glopara/dump}
datobs=$obs_datapath/${RUN}.${iy}${im}${id}/${ih}/atmos

# Set runtime and save directories
tmpdir=${tmpdir:-$datges/gsitmp$$}
mkdir -p $tmpdir
savdir=${savdir:-$datges}

# Specify GSI fixed field and data directories.
export fixgsi=${fixgsi:-$gsipath/fix}
export fixcrtm=${fixcrtm:-$basedir/nwprod/CRTM_Coefficients}
export HOMEGLOBAL=${HOMEGLOBAL:-/lfs1/projects/fim/whitaker/gfsenkf}
export FIXGLOBAL=${FIXGLOBAL:-$HOMEGLOBAL/fix}
export EXECGLOBAL=${EXECGLOBAL:-$HOMEGLOBAL/bin}

# Set variables used in script
#   CLEAN up $tmpdir when finished (YES=remove, NO=leave alone)
#   ndate is a date manipulation utility
#   ndate is a date manipulation utility
#   ncp is cp replacement, currently keep as /bin/cp

ncp="/bin/cp -f"
nmv="/bin/mv -f"
nln="/bin/ln -fs"

# go to $tmpdir
cd $tmpdir

echo "Time before global cycle `date` "

# Set the JCAP resolution which you want.
export JCAP_A=${JCAP_A:-$JCAP}
export LEVS=${LEVS:-127}
export JCAP_B=${JCAP_B:-$JCAP}
export lobsdiag_forenkf=${lobsdiag_forenkf:-".false."}


export NLAT=$((${LATA}+2))
JCAP_ENS=${JCAP_ENS:-$JCAP}
LATA_ENS=${LATA_ENS:-$LATA}
LONA_ENS=${LONA_ENS:-$LONA}
export NLAT_ENS=$((${LATA_ENS}+2))


SATANGO=${SATANGO:-$savdir/${RUN}.t${hha}z.satang}
BIASO=${BIASO:-$savdir/${RUN}.t${hha}z.abias}
BIASOAIR=${BIASOAIR:-$savdir/${RUN}.t${hha}z.abias_air}
BIASO_PC=${BIASO_PC:-$savdir/${RUN}.t${hha}z.abias_pc}

if [ "${iau_delthrs}" != "-1" ]; then
   lwrite4danl=.true.
else
   lwrite4danl=.false.
fi
if [[ $beta_s0 > 0.999 ]]; then
   lwrite4danl=.false.
fi
# if satwnd bufr file exists, use it.
if [[ -s $datobs/${prefix_obs}.satwnd.${suffix} ]]; then
   use_prepb_satwnd=.false.
else
   use_prepb_satwnd=.true.
fi
if [ $use_correlated_oberrs == ".true." ];  then
  lupdqc=.true.
else
  lupdqc=.false.
fi
SETUP="verbose=.true.,reduce_diag=.true.,lwrite_peakwt=.true.,lread_obs_save=$lread_obs_save,lread_obs_skip=$lread_obs_skip,l4densvar=.true.,ens_nstarthr=3,iwrtinc=-1,nhr_assimilation=6,nhr_obsbin=$FHOUT,use_prepb_satwnd=$use_prepb_satwnd,lwrite4danl=$lwrite4danl,passive_bc=.true.,newpc4pred=.true.,adp_anglebc=.true.,angord=4,use_edges=.false.,diag_precon=.true.,step_start=1.e-3,emiss_bc=.true.,lobsdiag_forenkf=$lobsdiag_forenkf,lwrite_predterms=.true.,thin4d=.true.,lupdqc=$lupdqc,nhr_anal=$iaufhrs"

if [[ "$HXONLY" = "YES" ]]; then
   #SETUP="$SETUP,lobserver=.true.,l4dvar=.true." # can't use reduce_diag=T
   SETUP="$SETUP,miter=0,niter=1"
fi
if [[ "$HXONLY" != "YES" ]]; then
   if [[ $beta_s0 > 0.999 ]]; then # 3dvar or hybrid gain
      STRONGOPTS="tlnmc_option=1,nstrong=1,nvmodes_keep=8,period_max=6.,period_width=1.5"
      if [ $NOOUTERLOOP == "YES" ]; then
         SETUP="$SETUP,miter=1,niter(1)=100,niter(2)=0,write_diag(1)=.true.,write_diag(2)=.true."
      else
         SETUP="$SETUP,miter=2,niter(1)=100,niter(2)=100,write_diag(1)=.true.,write_diag(2)=.false,write_diag(3)=.true."
      fi
   else # envar
      STRONGOPTS="tlnmc_option=3,nstrong=1,nvmodes_keep=48,period_max=6.,period_width=1.5,baldiag_full=.true.,baldiag_inc=.true.,"
      # balance constraint on 3dvar part of envar increment
      #STRONGOPTS="tlnmc_option=4,nstrong=1,nvmodes_keep=48,period_max=6.,period_width=1.5,baldiag_full=.true.,baldiag_inc=.true.,"
      # no strong bal constraint
      if [ $NOTLNMC == "YES" ]; then
         STRONGOPTS="tlnmc_option=0,nstrong=0,nvmodes_keep=0,baldiag_full=.false.,baldiag_inc=.false.,"
      fi
      if [ $NOOUTERLOOP == "YES" ]; then
         SETUP="$SETUP,miter=1,niter(1)=150,niter(2)=0"
      else
         SETUP="$SETUP,miter=2,niter(1)=100,niter(2)=100"
      fi
   fi
else
   STRONGOPTS="tlnmc_option=0,nstrong=0,nvmodes_keep=0,baldiag_full=.false.,baldiag_inc=.false.,"
fi
GRIDOPTS=${GRIDOPTS:-""}
BKGVERR=${BKGVERR:-""}
ANBKGERR=${ANBKGERR:-""}
JCOPTS=${JCOPTS:-""}
OBSQC=${OBSQC:-""}
# GSI defaults
#   tcp_width=50.0_r_kind
#   tcp_ermin=0.75_r_kind  
#   tcp_ermax=5.0_r_kind
OBSINPUT=${OBSINPUT:-""}
SUPERRAD=${SUPERRAD:-""}
SINGLEOB=${SINGLEOB:-""}
LAGDATA=${LAGDATA:-""}
RAPIDREFRESH_CLDSURF=${RAPIDREFRESH_CLDSURF:-""}
CHEM=${CHEM:-""}
#      l_hyb_ens:  logical variable, if .true., then turn on hybrid ensemble option, default = .false. 
#      n_ens:      ensemble size, default = 0
#      beta_s0:  value between 0 and 1, relative weight given to static background B, default = 1.0
#      s_ens_h:    horizontal localization correlation length (units of km), default = 2828.0
#      s_ens_v:    vertical localization correlation length (grid units), default = 30.0
#      generate_ens:  if .true., generate ensemble perturbations internally as random samples of background B.
#                       (used primarily for testing/debugging)
#                     if .false., read external ensemble perturbations (not active yet)
#      aniso_a_en: if .true., then allow anisotropic localization correlation (not active yet)
#      uv_hyb_ens: if .true., then ensemble perturbation wind stored as u,v
#                  if .false., ensemble perturbation wind stored as psi,chi.
#                   (this is useful for regional application, where there is ambiguity in how to
#                      define psi,chi from u,v)
beta_s0=${beta_s0:-0.25}
beta_e0=${beta_e0:-1.0}
s_ens_h=${s_ens_h:-400}
s_ens_v=${s_ens_v:-0.6}
# sat thinning params
dmesh1=${dmesh1:-145.0}
dmesh2=${dmesh2:-150.0}
dmesh3=${dmesh3:-100.0}
if [ "$HXONLY" = "NO" ] && [[ $beta_s0 < 0.999 ]]; then
HYBRIDENSDATA="l_hyb_ens=.true.,n_ens=$nens,beta_s0=$beta_s0,beta_e0=$beta_e0,s_ens_h=$s_ens_h,s_ens_v=$s_ens_v,generate_ens=.false.,uv_hyb_ens=.true.,jcap_ens=$JCAP_ENS,nlat_ens=$NLAT_ENS,nlon_ens=$LONA_ENS,aniso_a_en=.false.,jcap_ens_test=$JCAP_ENS,readin_localization=$readin_localization,write_ens_sprd=.false.,oz_univ_static=.false.,q_hyb_ens=.false.,ens_fast_read=.true.,readin_beta=$readin_beta"
else
HYBRIDENSDATA=""
#SETUP="$SETUP,l4densvar=.false."
fi

NST=${NST:-""}
if [ $NST_GSI -gt 0 ]; then
   NST="nstinfo=$NSTINFO,fac_dtl=$FAC_DTL,fac_tsl=$FAC_TSL,zsea1=$ZSEA1,zsea2=$ZSEA2,$NST"
fi

# Create global_gsi namelist
cat <<EOF > gsiparm.anl
 &SETUP
   niter_no_qc(1)=50,niter_no_qc(2)=0,
   netcdf_diag=.true.,binary_diag=.false.,
   qoption=2,
   factqmin=0.5,factqmax=0.0002,deltim=$DELTIM,
   tzr_qc=1,iguess=-1,
   oneobtest=.false.,retrieval=.false.,l_foto=.false.,
   use_pbl=.false.,use_compress=.true.,nsig_ext=$nsig_ext,gpstop=$gpstop.,
   use_gfs_ncio=.true.,sfcnst_comb=.true.,cwoption=3,imp_physics=${imp_physics},
   write_fv3_incr=$write_fv3_increment,
   crtm_coeffs_path='./crtm_coeffs/',
   $WRITE_INCR_ZERO
   $WRITE_ZERO_STRAT
   $WRITE_STRAT_EFOLD
   $SETUP
 /
 &GRIDOPTS
   JCAP_B=$JCAP_B,JCAP=$JCAP_A,NLAT=$NLAT,NLON=$LONA,nsig=$LEVS,
   regional=.false.,
   $GRIDOPTS
 /
 &BKGERR
   vs=0.7,
   hzscl=1.7,0.8,0.5,
   hswgt=0.45,0.3,0.25,
   bw=0.0,norsp=4,
   bkgv_flowdep=.false.,bkgv_rewgtfct=1.5,
   bkgv_write=.false.,
   cwcoveqqcov=.false.,
   $BKGVERR
 /
 &ANBKGERR
   anisotropic=.false.,
   $ANBKGERR
 /
 &JCOPTS
   ljcdfi=.false.,alphajc=0.0,ljcpdry=.false.,bamp_jcpdry=5.0e7,ljc4tlevs=.true.
   $JCOPTS
 /
 &STRONGOPTS
   $STRONGOPTS
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.true.,oberrflg=.false.,c_varqc=0.04,
   use_poq7=.true.,qc_noirjaco3_pole=.true.,vqc=.false.,nvqc=.true.,
   aircraft_t_bc=$aircraft_t_bc,biaspredt=1.0e5,upd_aircraft=$upd_aircraft,cleanup_tail=.true.,
   tcp_width=60.0,tcp_ermin=2.0,tcp_ermax=12.0,
   $OBSQC
 /
 /
 &OBS_INPUT
   dmesh(1)=$dmesh1,dmesh(2)=$dmesh2,dmesh(3)=$dmesh3,time_window_max=3.0,
  $OBSINPUT
/
OBS_INPUT::
!  dfile          dtype       dplat       dsis                dval    dthin  dsfcalc
   prepbufr       ps          null        ps                  0.0     0      0
   prepbufr       t           null        t                   0.0     0      0
   prepbufr       q           null        q                   0.0     0      0
   prepbufr       pw          null        pw                  0.0     0      0
   prepbufr_profl t           null        t                   0.0     0      0
   prepbufr_profl q           null        q                   0.0     0      0
   prepbufr_profl uv          null        uv                  0.0     0      0
   satwndbufr     uv          null        uv                  0.0     0      0
   prepbufr       uv          null        uv                  0.0     0      0
   prepbufr       spd         null        spd                 0.0     0      0
   prepbufr       dw          null        dw                  0.0     0      0
   radarbufr      rw          null        rw                  0.0     0      0
   nsstbufr       sst         nsst        sst                 0.0     0      0
   gpsrobufr      gps_bnd     null        gps                 0.0     0      0
   ssmirrbufr     pcp_ssmi    dmsp        pcp_ssmi            0.0    -1      0
   tmirrbufr      pcp_tmi     trmm        pcp_tmi             0.0    -1      0
   sbuvbufr       sbuv2       nim07       sbuv8_nim07         0.0     0      0
   sbuvbufr       sbuv2       n09         sbuv8_n09           0.0     0      0
   sbuvbufr       sbuv2       n11         sbuv8_n11           0.0     0      0
   sbuvbufr       sbuv2       n14         sbuv8_n14           0.0     0      0
   sbuvbufr       sbuv2       n16         sbuv8_n16           0.0     0      0
   sbuvbufr       sbuv2       n17         sbuv8_n17           0.0     0      0
   sbuvbufr       sbuv2       n18         sbuv8_n18           0.0     0      0
   sbuvbufr       sbuv2       n19         sbuv8_n19           0.0     0      0
   hirs2bufr      hirs2       tirosn      hirs2_tirosn        0.0     1      1
   hirs2bufr      hirs2       n06         hirs2_n06           0.0     1      1
   hirs2bufr      hirs2       n07         hirs2_n07           0.0     1      1
   hirs2bufr      hirs2       n07         hirs2_n08           0.0     1      1
   hirs2bufr      hirs2       n07         hirs2_n09           0.0     1      1
   hirs2bufr      hirs2       n10         hirs2_n10           0.0     1      1
   hirs2bufr      hirs2       n11         hirs2_n11           0.0     1      1
   hirs2bufr      hirs2       n12         hirs2_n12           0.0     1      1
   hirs2bufr      hirs2       n14         hirs2_n14           0.0     1      1
   hirs3bufr      hirs3       n15         hirs3_n15           0.0     1      1
   hirs3bufr      hirs3       n16         hirs3_n16           0.0     1      1
   hirs3bufr      hirs3       n17         hirs3_n17           0.0     1      1
   gimgrbufr      goes_img    g11         imgr_g11            0.0     1      0
   gimgrbufr      goes_img    g12         imgr_g12            0.0     1      0
   airsbufr       airs        aqua        airs_aqua           0.0     1      1
   msubufr        msu         tirosn      msu_tirosn          0.0     1      1
   msubufr        msu         n06         msu_n06             0.0     1      1
   msubufr        msu         n07         msu_n07             0.0     1      1
   msubufr        msu         n08         msu_n08             0.0     1      1
   msubufr        msu         n09         msu_n09             0.0     1      1
   msubufr        msu         n10         msu_n10             0.0     1      1
   msubufr        msu         n11         msu_n11             0.0     1      1
   msubufr        msu         n12         msu_n12             0.0     1      1
   msubufr        msu         n14         msu_n14             0.0     1      1
   ssubufr        ssu         tirosn      ssu_tirosn          0.0     1      1
   ssubufr        ssu         n06         ssu_n06             0.0     1      1
   ssubufr        ssu         n07         ssu_n07             0.0     1      1
   ssubufr        ssu         n08         ssu_n08             0.0     1      1
   ssubufr        ssu         n09         ssu_n09             0.0     1      1
   ssubufr        ssu         n11         ssu_n11             0.0     1      1
   ssubufr        ssu         n14         ssu_n14             0.0     1      1
   amsuabufr      amsua       n15         amsua_n15           0.0     1      1
   amsuabufr      amsua       n16         amsua_n16           0.0     1      1
   amsuabufr      amsua       n17         amsua_n17           0.0     1      1
   amsuabufr      amsua       n18         amsua_n18           0.0     1      1
   airsbufr       amsua       aqua        amsua_aqua          0.0     1      1
   amsubbufr      amsub       n15         amsub_n15           0.0     1      1
   amsubbufr      amsub       n16         amsub_n16           0.0     1      1
   amsubbufr      amsub       n17         amsub_n17           0.0     1      1
   mhsbufr        mhs         n18         mhs_n18             0.0     1      1
   ssmitbufr      ssmi        f08         ssmi_f08            0.0     1      0
   ssmitbufr      ssmi        f10         ssmi_f10            0.0     1      0
   ssmitbufr      ssmi        f11         ssmi_f11            0.0     1      0
   ssmitbufr      ssmi        f13         ssmi_f13            0.0     1      0
   ssmitbufr      ssmi        f14         ssmi_f14            0.0     1      0
   ssmitbufr      ssmi        f15         ssmi_f15            0.0     1      0
   amsrebufr      amsre_low   aqua        amsre_aqua          0.0     1      0
   amsrebufr      amsre_mid   aqua        amsre_aqua          0.0     1      0
   amsrebufr      amsre_hig   aqua        amsre_aqua          0.0     1      0
   ssmisbufr      ssmis       f16         ssmis_f16           0.0     1      0
   ssmisbufr      ssmis       f17         ssmis_f17           0.0     1      0
   ssmisbufr      ssmis       f18         ssmis_f18           0.0     1      0
   ssmisbufr      ssmis       f19         ssmis_f19           0.0     1      0
   gsnd1bufr      sndr        g08         sndr_g08            0.0     1      0
   gsnd1bufr      sndr        g09         sndr_g09            0.0     1      0
   gsnd1bufr      sndr        g10         sndr_g10            0.0     1      0
   gsnd1bufr      sndr        g11         sndr_g11            0.0     1      0
   gsnd1bufr      sndr        g12         sndr_g12            0.0     1      0
   gsnd1bufr      sndrd1      g12         sndrD1_g12          0.0     1      0
   gsnd1bufr      sndrd2      g12         sndrD2_g12          0.0     1      0
   gsnd1bufr      sndrd3      g12         sndrD3_g12          0.0     1      0
   gsnd1bufr      sndrd4      g12         sndrD4_g12          0.0     1      0
   gsnd1bufr      sndrd1      g11         sndrD1_g11          0.0     1      0
   gsnd1bufr      sndrd2      g11         sndrD2_g11          0.0     1      0
   gsnd1bufr      sndrd3      g11         sndrD3_g11          0.0     1      0
   gsnd1bufr      sndrd4      g11         sndrD4_g11          0.0     1      0
   gsnd1bufr      sndrd1      g13         sndrD1_g13          0.0     1      0
   gsnd1bufr      sndrd2      g13         sndrD2_g13          0.0     1      0
   gsnd1bufr      sndrd3      g13         sndrD3_g13          0.0     1      0
   gsnd1bufr      sndrd4      g13         sndrD4_g13          0.0     1      0
   gsnd1bufr      sndrd1      g14         sndrD1_g14          0.0     1      0
   gsnd1bufr      sndrd2      g14         sndrD2_g14          0.0     1      0
   gsnd1bufr      sndrd3      g14         sndrD3_g14          0.0     1      0
   gsnd1bufr      sndrd4      g14         sndrD4_g14          0.0     1      0
   gsnd1bufr      sndrd1      g15         sndrD1_g15          0.0     1      0
   gsnd1bufr      sndrd2      g15         sndrD2_g15          0.0     1      0
   gsnd1bufr      sndrd3      g15         sndrD3_g15          0.0     1      0
   gsnd1bufr      sndrd4      g15         sndrD4_g15          0.0     1      0
   hirs4bufr      hirs4       n19         hirs4_n19           0.0     1      1
   amsuabufr      amsua       n19         amsua_n19           0.0     1      1
   mhsbufr        mhs         n19         mhs_n19             0.0     1      1
   tcvitl         tcp         null        tcp                 0.0     0      0
   seviribufr     seviri      m08         seviri_m08          0.0     1      0
   seviribufr     seviri      m09         seviri_m09          0.0     1      0
   seviribufr     seviri      m10         seviri_m10          0.0     1      0
   seviribufr     seviri      m10         seviri_m11          0.0     1      0
   hirs4bufr      hirs4       metop-a     hirs4_metop-a       0.0     1      1
   hirs4bufr      hirs4       metop-b     hirs4_metop-b       0.0     1      0
   amsuabufr      amsua       metop-a     amsua_metop-a       0.0     1      1
   amsuabufr      amsua       metop-b     amsua_metop-b       0.0     1      0
   amsuabufr      amsua       metop-c     amsua_metop-c       0.0     1      0
   mhsbufr        mhs         metop-a     mhs_metop-a         0.0     1      1
   mhsbufr        mhs         metop-b     mhs_metop-b         0.0     1      0
   mhsbufr        mhs         metop-c     mhs_metop-c         0.0     1      0
   iasibufr       iasi        metop-a     iasi_metop-a        0.0     1      1
   iasibufr       iasi        metop-b     iasi_metop-b        0.0     1      0
   iasibufr       iasi        metop-c     iasi_metop-c        0.0     1      0
   gomebufr       gome        metop-a     gome_metop-a        0.0     2      0
   gomebufr       gome        metop-b     gome_metop-b        0.0     2      0
   gomebufr       gome        metop-c     gome_metop-c        0.0     2      0
   atmsbufr       atms        npp         atms_npp            0.0     1      1
   atmsbufr       atms        n20         atms_n20            0.0     1      1
   atmsbufr       atms        n20         atms_n21            0.0     1      1
   crisbufr       cris        npp         cris_npp            0.0     1      0
   crisfsbufr     cris-fsr    npp         cris-fsr_npp        0.0     1      0
   crisfsbufr     cris-fsr    n20         cris-fsr_n20        0.0     1      0
   crisfsbufr     cris-fsr    n21         cris-fsr_n21        0.0     1      0
   avhambufr      avhrr       n15         avhrr3_n15          0.0     1      0
   avhambufr      avhrr       n17         avhrr3_n17          0.0     1      0
   avhambufr      avhrr       metop-a     avhrr3_metop-a      0.0     1      0
   avhambufr      avhrr       metop-b     avhrr3_metop-b      0.0     1      0
   avhambufr      avhrr       metop-c     avhrr3_metop-c      0.0     1      0
   avhpmbufr      avhrr       n14         avhrr2_n14          0.0     1      0
   avhpmbufr      avhrr       n16         avhrr3_n16          0.0     1      0
   avhpmbufr      avhrr       n18         avhrr3_n18          0.0     1      0
   avhpmbufr      avhrr       n19         avhrr3_n19          0.0     1      0
   oscatbufr      uv          null        uv                  0.0     0      0
   amsr2bufr      amsr2       gcom-w1     amsr2_gcom-w1       0.0     3      0
   gmibufr        gmi         gpm         gmi_gpm             0.0     3      0
   saphirbufr     saphir      meghat      saphir_meghat       0.0     3      0
   ahibufr        ahi         himawari8   ahi_himawari8       0.0     1      0
   ahibufr        ahi         himawari9   ahi_himawari9       0.0     1      0
   abibufr        abi         g16         abi_g16             0.0     1      0
   abibufr        abi         g17         abi_g17             0.0     1      0
   abibufr        abi         g18         abi_g18             0.0     1      0
   rapidscatbufr  uv          null        uv                  0.0     0      0
   amsuabufr      amsua       metop-c     amsua_metop-c       0.0     1      1
   mhsbufr        mhs         metop-c     mhs_metop-c         0.0     1      1
   iasibufr       iasi        metop-c     iasi_metop-c        0.0     1      1
   mlsbufr        mls30       aura        mls30_aura          0.0     0      0
!--ozone bufr dumps
   ompsnpbufr     ompsnp      npp         ompsnp_npp          0.0     0      0
   ompsnpbufr     ompsnp      n20         ompsnp_n20          0.0     0      0
   ompstcbufr     ompstc8     npp         ompstc8_npp         0.0     2      0
   ompstcbufr     ompstc8     n20         ompstc8_n20         0.0     2      0
   omibufr        omi         aura        omi_aura            0.0     2      0
!--nasa netcdf ozone (can't have both bufr and netcdf versions at the same time)
!  ompslpnc       ompslpnc    npp         ompslpnc_npp        0.0     0      0
!  ompsnmeffnc    ompsnmeff   npp         ompsnmeff_npp       0.0     0      0
!  mls55nc        mls55       aura        mls55_aura          0.0     0      0
!  omieffnc       omieff      aura        omieff_aura         0.0     2      0
::
 &SUPEROB_RADAR
   $SUPERRAD
 /
 &LAG_DATA
   $LAGDATA
 /
 &HYBRID_ENSEMBLE
   $HYBRIDENSDATA
 /
 &RAPIDREFRESH_CLDSURF
   dfi_radar_latent_heat_time_period=30.0,
   $RAPIDREFRESH_CLDSURF
 /
 &CHEM
   $CHEM
 /
 &SINGLEOB_TEST
   maginnov=0.1,magoberr=0.1,oneob_type='t',
   oblat=45.,oblon=180.,obpres=1000.,obdattim=${CDATE},
   obhourset=0.,
   $SINGLEOB
 /
&NST
  nst_gsi=$NST_GSI,
  $NST
/
EOF

# Set fixed files
#   berror   = forecast model background error statistics
#   satinfo  = text file with information about assimilation of brightness temperatures
#   satangl  = angle dependent bias correction file (fixed in time)
#   pcpinfo  = text file with information about assimilation of prepcipitation rates
#   ozinfo   = text file with information about assimilation of ozone data
#   errtable = text file with obs error for conventional data (optional)
#   convinfo = text file with information about assimilation of conventional data
#   bufrtable= text file ONLY needed for single obs test (oneobstest=.true.)
#   bftab_sst= bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)

berror=${BERROR:-$fixgsi/Big_Endian/global_berror.l${LEVS}y${NLAT}.f77}

satinfo=${SATINFO:-$fixgsi/global_satinfo.txt}
atmsfilter=${ATMSFILTER:-$fixgsi/atms_beamwidth.txt}
scaninfo=$fixgsi/global_scaninfo.txt
satangl=$fixgsi/global_satangbias.txt
pcpinfo=$fixgsi/global_pcpinfo.txt
ozinfo=${OZINFO:-$fixgsi/global_ozinfo.txt}
convinfo=${CONVINFO:-$fixgsi/global_convinfo.txt}
insituinfo=${INSITUINFO:-$fixgsi/global_insituinfo.txt}
aeroinfo=${AEROINFO:-$fixgsi/global_aeroinfo.txt}
errtable=$fixgsi/prepobs_errtable.global
anavinfo=${ANAVINFO:-$fixgsi/global_anavinfo.l${LEVS}txt}
radcloudinfo=${RADCLOUDINFO:-${fixgsi}/cloudy_radiance_info.txt}
vqcdat=${vqcdat:-${fixgsi}/vqctp001.dat}

# Only need this file for single obs test
bufrtable=$fixgsi/prepobs_prep.bufrtable

# Only need this file for sst retrieval
bftab_sst=$fixgsi/bufrtab.012

# Copy executable and fixed files to $tmpdir
if [[ "$lread_obs_skip" = ".false." ]]; then

$nln $gsiexec ./gsi.x

$ncp $anavinfo ./anavinfo
$ncp $radcloudinfo ./cloudy_radiance_info.txt
$nln $berror   ./berror_stats
$nln $satangl  ./satbias_angle
$nln $satinfo  ./satinfo
$nln $atmsfilter ./atms_beamwidth.txt
$nln $scaninfo ./scaninfo
$nln $pcpinfo  ./pcpinfo
$nln $ozinfo   ./ozinfo
$nln $convinfo ./convinfo
$nln $insituinfo ./insituinfo
$nln $aeroinfo ./aeroinfo
$nln $errtable ./errtable
$nln $vqcdat   ./vqctp001.dat

$nln $bufrtable ./prepobs_prep.bufrtable
$nln $bftab_sst ./bftab_sstphr

# if correlated ob errors desired, link Rcov files.
if [ $use_correlated_oberrs == ".true." ];  then
  if grep -q "Rcov" $anavinfo ; then
     if ls ${fixgsi}/Rcov* 1> /dev/null 2>&1; then
       $nln ${fixgsi}/Rcov* $tmpdir
       echo "using correlated obs error"
     else
       echo "Error: Satellite error covariance files are missing."
       echo "Check for the required Rcov files in " $anavinfo
       exit 1
     fi
  else
     echo "Error: Satellite error covariance info missing in " $anavinfo
     exit 1
  fi
else
  echo "not using correlated obs error"
fi


GBIAS=${GBIAS:-$datgesm1/${prefix_tbc}.abias}
GBIAS_PC=${GBIAS_PC:-$datgesm1/${prefix_tbc}.abias_pc}
GBIASAIR=${GBIASAIR:-$datgesm1/${prefix_tbc}.abias_air}
GSATANG=${GSATANG:-$datgesm1/${prefix_tbc}.satang}

##############################################################
# CRTM Spectral and Transmittance coefficients
mkdir -p crtm_coeffs
for file in $(awk '{if($1!~"!"){print $1}}' satinfo | sort | uniq); do
   $nln $fixcrtm/${file}.SpcCoeff.bin ./crtm_coeffs/${file}.SpcCoeff.bin
   $nln $fixcrtm/${file}.TauCoeff.bin ./crtm_coeffs/${file}.TauCoeff.bin
done

$nln $fixcrtm/Nalli.IRwater.EmisCoeff.bin   ./crtm_coeffs/Nalli.IRwater.EmisCoeff.bin
$nln $fixcrtm/NPOESS.IRice.EmisCoeff.bin    ./crtm_coeffs/NPOESS.IRice.EmisCoeff.bin
$nln $fixcrtm/NPOESS.IRland.EmisCoeff.bin   ./crtm_coeffs/NPOESS.IRland.EmisCoeff.bin
$nln $fixcrtm/NPOESS.IRsnow.EmisCoeff.bin   ./crtm_coeffs/NPOESS.IRsnow.EmisCoeff.bin
$nln $fixcrtm/NPOESS.VISice.EmisCoeff.bin   ./crtm_coeffs/NPOESS.VISice.EmisCoeff.bin
$nln $fixcrtm/NPOESS.VISland.EmisCoeff.bin  ./crtm_coeffs/NPOESS.VISland.EmisCoeff.bin
$nln $fixcrtm/NPOESS.VISsnow.EmisCoeff.bin  ./crtm_coeffs/NPOESS.VISsnow.EmisCoeff.bin
$nln $fixcrtm/NPOESS.VISwater.EmisCoeff.bin ./crtm_coeffs/NPOESS.VISwater.EmisCoeff.bin
$nln $fixcrtm/FASTEM6.MWwater.EmisCoeff.bin ./crtm_coeffs/FASTEM6.MWwater.EmisCoeff.bin
$nln $fixcrtm/AerosolCoeff.bin              ./crtm_coeffs/AerosolCoeff.bin
$nln $fixcrtm/CloudCoeff.bin                ./crtm_coeffs/CloudCoeff.bin

# link observational data to $tmpdir
if [[ ! -s $datobs/${prefix_obs}.prepbufr ]]; then
 echo "no prepbufr file!"
 exit 1
fi 

if [[ "$NOCONV" = "NO" ]]; then
$nln $datobs/${prefix_obs}.prepbufr           ./prepbufr
if [[ -s $datobs/${prefix_obs}.nsstbufr ]]; then
$nln ${datobs}/${prefix_obs}.nsstbufr ./nsstbufr
fi
if [[ -s $datobs/${prefix_obs}.prepbufr.acft_profiles ]]; then
$nln $datobs/${prefix_obs}.prepbufr.acft_profiles ./prepbufr_profl
fi
if [[ -s $datobs/${prefix_obs}.syndata.tcvitals.tm00 ]]; then
$nln $datobs/${prefix_obs}.syndata.tcvitals.tm00     ./tcvitl
fi
if [[ -s $datobs/${prefix_obs}.gpsro.${suffix} ]]; then
$nln $datobs/${prefix_obs}.gpsro.${suffix}    ./gpsrobufr
fi
if [[ -s $datobs/${prefix_obs}.satwnd.${suffix} ]]; then
$nln $datobs/${prefix_obs}.satwnd.${suffix}      ./satwndbufr
fi
if [[ -s $datobs/${prefix_obs}.oscatw.${suffix} ]]; then
$nln $datobs/${prefix_obs}.oscatw.${suffix}      ./oscatbufr
fi
if [[ -s $datobs/${prefix_obs}.rapidscatw.${suffix} ]]; then
$nln $datobs/${prefix_obs}.rapidscatw.${suffix}      ./rapidscatbufr
fi
fi

if [[ "$NOSAT" = "NO" ]]; then
if [[ "$NOCONV" = "NO" ]]; then
# use nasa sbuv8 if available
if [[ -s $datobs/${prefix_obs}.sbuv8_v87.${suffix} ]]; then
$nln $datobs/${prefix_obs}.sbuv8_v87.${suffix}   ./sbuvbufr
elif [[ -s $datobs/${prefix_obs}.osbuv8.${suffix} ]]; then
$nln $datobs/${prefix_obs}.osbuv8.${suffix}   ./sbuvbufr
fi
fi
if [[ -s $datobs/${prefix_obs}.1bamua.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bamua.${suffix}   ./amsuabufr
fi
if [[ -s $datobs/${prefix_obs}.1bmsu.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bmsu.${suffix}   ./msubufr
fi
if [[ -s $datobs/${prefix_obs}.1bssu.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bssu.${suffix}   ./ssubufr
fi
if [[ -s $datobs/${prefix_obs}.1bmhs.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bmhs.${suffix}    ./mhsbufr
fi
if [[ -s $datobs/${prefix_obs}.atms.${suffix} ]]; then
$nln $datobs/${prefix_obs}.atms.${suffix}      ./atmsbufr
fi
if [[ -s $datobs/${prefix_obs}.goesnd.${suffix} ]]; then
$nln $datobs/${prefix_obs}.goesnd.${suffix}   ./gsnd1bufr
fi
if [[ -s $datobs/${prefix_obs}.goesnd.${suffix} ]]; then
$nln $datobs/${prefix_obs}.geoimr.${suffix}   ./gimgrbufr
fi
if [[ -s $datobs/${prefix_obs}.1bamub.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bamub.${suffix}   ./amsubbufr
fi
if [[ -s $datobs/${prefix_obs}.1bhrs2.${suffix}  ]]; then
$nln $datobs/${prefix_obs}.1bhrs2.${suffix}   ./hirs2bufr
fi
if [[ -s $datobs/${prefix_obs}.1bhrs3.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bhrs3.${suffix}   ./hirs3bufr
fi
if [[ -s $datobs/${prefix_obs}.1bhrs4.${suffix} ]]; then
$nln $datobs/${prefix_obs}.1bhrs4.${suffix}   ./hirs4bufr
fi
if [[ -s $datobs/${prefix_obs}.airsev.${suffix} ]]; then
$nln $datobs/${prefix_obs}.airsev.${suffix}   ./airsbufr
fi
if [[ -s $datobs/${prefix_obs}.mtiasi.${suffix} ]]; then
$nln $datobs/${prefix_obs}.mtiasi.${suffix}   ./iasibufr
fi
if [[ -s $datobs/${prefix_obs}.iasidb.${suffix} ]]; then
$nln $datobs/${prefix_obs}.iasidb.${suffix}   ./iasibufr_db
fi
if [[ -s $datobs/${prefix_obs}.ssmit.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ssmit.${suffix}    ./ssmitbufr
fi
if [[ -s  $datobs/${prefix_obs}.amsre.${suffix} ]]; then
$nln $datobs/${prefix_obs}.amsre.${suffix}    ./amsrebufr
fi
if [[ -s  $datobs/${prefix_obs}.amsr2.${suffix} ]]; then
$nln $datobs/${prefix_obs}.amsr2.${suffix}    ./amsr2bufr
fi
if [[ -s $datobs/${prefix_obs}.ssmis.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ssmis.${suffix}    ./ssmisbufr
fi
if [[ -s $datobs/${prefix_obs}.ssmit.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ssmit.${suffix}    ./ssmitbufr
fi
if [[ -s $datobs/${prefix_obs}.gome.${suffix} ]]; then
$nln $datobs/${prefix_obs}.gome.${suffix}     ./gomebufr
fi

if [[ -s $datobs/OMIeff-adj.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/OMIeff-adj.${yyyymmdda}_${hha}z.nc omieffnc
fi
if [[ -s $datobs/${prefix_obs}.omi.${suffix} ]]; then
$nln $datobs/${prefix_obs}.omi.${suffix}      ./omibufr
fi
if [[ -s $datobs/OMPSNM.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/OMPSNM.${yyyymmdda}_${hha}z.nc ompsnmeffnc
fi
if [[ -s $datobs/${prefix_obs}.ompsn8.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ompsn8.${suffix}     ./ompsnpbufr
fi
if [[ -s $datobs/${prefix_obs}.ompst8.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ompst8.${suffix}     ./ompstcbufr
fi
if [[ -s $datobs/OMPS-LPoz-Vis.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/OMPS-LPoz-Vis.${yyyymmdda}_${hha}z.nc ompslpnc
fi
if [[ -s $datobs/MLS-v5.0-oz.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/MLS-v5.0-oz.${yyyymmdda}_${hha}z.nc mls55nc
fi
if [[ -s $datobs/${prefix_obs}.mls.${suffix} ]]; then
$nln $datobs/${prefix_obs}.mls.${suffix}      ./mlsbufr
fi
 
if [[ -s $datobs/${prefix_obs}.sevcsr.${suffix} ]]; then
$nln $datobs/${prefix_obs}.sevcsr.${suffix}      ./seviribufr
fi
if [[ -s $datobs/${prefix_obs}.ahicsr.${suffix} ]]; then
$nln $datobs/${prefix_obs}.ahicsr.${suffix}      ./ahibufr
fi
if [[ -s $datobs/${prefix_obs}.gsrcsr.${suffix} ]]; then
$nln $datobs/${prefix_obs}.gsrcsr.${suffix}      ./abibufr
fi
if [[ -s $datobs/${prefix_obs}.gm1cr.${suffix} ]]; then
$nln $datobs/${prefix_obs}.gm1cr.${suffix}      ./gmibufr
fi
if [[ -s $datobs/${prefix_obs}.cris.${suffix} ]]; then
$nln $datobs/${prefix_obs}.cris.${suffix}      ./crisbufr
fi
if [[ -s $datobs/${prefix_obs}.crisf4.${suffix} ]]; then
$nln $datobs/${prefix_obs}.crisf4.${suffix}      ./crisfsbufr
fi
if [[ -s $datobs/${prefix_obs}.spssmi.${suffix} ]]; then
$nln $datobs/${prefix_obs}.spssmi.${suffix}   ./ssmirrbufr
fi
if [[ -s $datobs/${prefix_obs}.sptrmm.${suffix} ]]; then
$nln $datobs/${prefix_obs}.sptrmm.${suffix}   ./tmirrbufr
fi
if [[ -s $datobs/${prefix_obs}.avcsam.${suffix} ]]; then
$nln $datobs/${prefix_obs}.avcsam.${suffix}          avhambufr
fi
if [[ -s $datobs/${prefix_obs}.avcspm.${suffix} ]]; then
$nln $datobs/${prefix_obs}.avcspm.${suffix}          avhpmbufr
fi
if [[ -s $datobs/OMIeff-adj.${pdy}_${cyc}z.nc ]]; then
$nln $datobs/OMIeff-adj.${yyyymmdda}_${hha}z.nc omieffnc
fi
if [[ -s MLS-v5.0-oz.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/MLS-v5.0-oz.${yyyymmdda}_${hha}z.nc mls55nc
fi
if [[ -s OMPS-LPoz-Vis.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/OMPS-LPoz-Vis.${yyyymmdda}_${hha}z.nc ompslpnc
fi
if [[ -s OMPSNM.${yyyymmdda}_${hha}z.nc ]]; then
$nln $datobs/OMPSNM.${yyyymmdda}_${hha}z.nc ompsnmeffnc
fi
fi # NOSAT

# link bias correction, atmospheric and surface files
$nln $GBIAS              ./satbias_in
$nln $GBIAS_PC           ./satbias_pc
$nln $GSATANG            ./satbias_angle
$nln $GBIASAIR           ./aircftbias_in

SFCG03=${SFCG03:-$datges/bfg_${adate}_fhr03_${charnanal}}
$nln $SFCG03               ./sfcf03
SFCG06=${SFCG06:-$datges/bfg_${adate}_fhr06_${charnanal}}
$nln $SFCG06               ./sfcf06
SFCG09=${SFCG09:-$datges/bfg_${adate}_fhr09_${charnanal}}
$nln $SFCG09               ./sfcf09

SIGG03=${SIGG03:-$datges/sfg_${adate}_fhr03_${charnanal}}
$nln $SIGG03               ./sigf03
SIGG06=${SIGG06:-$datges/sfg_${adate}_fhr06_${charnanal}}
$nln $SIGG06               ./sigf06
SIGG09=${SIGG09:-$datges/sfg_${adate}_fhr09_${charnanal}}
$nln $SIGG09               ./sigf09

if [[ "$HRLY_BKG" = "YES" ]]; then
SFCG04=${SFCG04:-$datges/bfg_${adate}_fhr04_${charnanal}}
$nln $SFCG04               ./sfcf04
SFCG05=${SFCG05:-$datges/bfg_${adate}_fhr05_${charnanal}}
$nln $SFCG05               ./sfcf05
SFCG07=${SFCG07:-$datges/bfg_${adate}_fhr07_${charnanal}}
$nln $SFCG07               ./sfcf07
SFCG08=${SFCG08:-$datges/bfg_${adate}_fhr08_${charnanal}}
$nln $SFCG08               ./sfcf08
SIGG04=${SIGG04:-$datges/sfg_${adate}_fhr04_${charnanal}}
$nln $SIGG04               ./sigf04
SIGG05=${SIGG05:-$datges/sfg_${adate}_fhr05_${charnanal}}
$nln $SIGG05               ./sigf05
SIGG07=${SIGG07:-$datges/sfg_${adate}_fhr07_${charnanal}}
$nln $SIGG07               ./sigf07
SIGG08=${SIGG08:-$datges/sfg_${adate}_fhr08_${charnanal}}
$nln $SIGG08               ./sigf08
fi

if [[ $beta_s0 < 0.999 ]]; then
ln -s $datges/ensmem*.pe* .
ln -s $datges/control*.pe* .
fh=3
while [ $fh -le 9 ] ;do
for ensfile in $datges/sfg_${adate}*fhr0${fh}*mem???; do
 ensfilename=`basename $ensfile`
 memnum=`echo $ensfilename | cut -f4 -d"_" | cut -c4-6`
 $nln $ensfile ./sigf0${fh}_ens_mem${memnum}
done
((fh+=$FHOUT))
done
fi
fi

# make symlinks for diag files to initialize angle dependent bias correction for new channels.
satdiag=$(cat ${scriptsdir}/build_gsinfo/satinfo/satellites)
ozdiag=$(cat ${scriptsdir}/build_gsinfo/ozinfo/satellites)
alldiag="$satdiag $ozdiag conv_tcp conv_gps conv_t conv_q conv_uv conv_ps"
string='ges'
for type in $satdiag; do
    if [ -s $datges/diag_${type}_${string}.${adate}_${charnanal2}.nc4 ]; then
       ln -fs $datges/diag_${type}_${string}.${adate}_${charnanal2}.nc4 diag_${type}.nc4
    elif [ -s $datgesm1/diag_${type}_${string}.${adatem1}_${charnanal2}.nc4 ]; then
       ln -fs $datgesm1/diag_${type}_${string}.${adatem1}_${charnanal2}.nc4 diag_${type}.nc4
    fi
done

# Run gsi.
#if [ -s ./satbias_in ] && [ -s ./satbias_angle ] && [ -s ./sfcf03 ] && [ -s ./sfcf06 ] && [ -s ./sfcf09 ] && [ -s ./sigf03 ] && [ -s ./sigf06 ] && [ -s ./sigf09 ] ; then
if [[ $NOSAT == "YES" ||  -s ./satbias_in ]]  && [ -s ./sfcf03 ] && [ -s ./sfcf06 ] && [ -s ./sfcf09 ] && [ -s ./sigf03 ] && [ -s ./sigf06 ] && [ -s ./sigf09 ] ; then
cat gsiparm.anl
ulimit -s unlimited

pwd
ls -l
echo "Time before GSI `date` "
export PGM=$tmpdir/gsi.x
${scriptsdir}/runmpi
rc=$?
#if [[ $rc -ne 0 ]];then
#  echo "GSI failed with exit code $rc"
#  exit $rc
#fi
else
echo "some input files missing, exiting ..."
ls -l ./satbias_in
ls -l ./satbias_angle
ls -l ./sfcf03
ls -l ./sfcf06
ls -l ./sfcf09
ls -l ./sigf03
ls -l ./sigf06
ls -l ./sigf09
exit 1
fi
ls -l

# Save output
mkdir -p $savdir

cat fort.2* > $savdir/gsistats.${adate}_${charnanal2}

#ls -l
if [[ "$HXONLY" = "NO" ]]; then
   if [ -s ./siganl ] && [ -s ./satbias_out ]; then
      if [ -s ./siga03 ]; then
         $nmv siga03          $SIGANL03
      fi
      if [ -s ./siga04 ]; then
         $nmv siga04          $SIGANL04
      fi
      if [ -s ./siga05 ]; then
         $nmv siga05          $SIGANL05
      fi
      $nmv siganl             $SIGANL06
      if [ -s ./siga07 ]; then
          $nmv siga07         $SIGANL07
      fi
      if [ -s ./siga08 ]; then
         $nmv siga08          $SIGANL08
      fi
      if [ -s ./siga09 ]; then
         $nmv siga09          $SIGANL09
      fi
      $nmv satbias_out $BIASO
      $nmv satbias_pc.out $BIASO_PC
      if [ -s aircftbias_out ]; then
      $nmv aircftbias_out $BIASOAIR
      fi
      if [ $DONST = "YES" ]; then
         $nmv dtfanl $DTFANL 
      fi
   elif [ -s ./siginc.nc ] && [ -s ./satbias_out ]; then
      if [ -s ./sigi03.nc ]; then
         $nmv sigi03.nc          $SIGANL03
      fi
      if [ -s ./sigi04.nc ]; then
         $nmv sigi04.nc          $SIGANL04
      fi
      if [ -s ./sigi05.nc ]; then
         $nmv sigi05.nc          $SIGANL05
      fi
      $nmv siginc.nc             $SIGANL06
      if [ -s ./sigi07.nc ]; then
          $nmv sigi07.nc         $SIGANL07
      fi
      if [ -s ./sigi08.nc ]; then
         $nmv sigi08.nc          $SIGANL08
      fi
      if [ -s ./sigi09.nc ]; then
         $nmv sigi09.nc          $SIGANL09
      fi
      $nmv satbias_out $BIASO
      $nmv satbias_pc.out $BIASO_PC
      if [ -s aircftbias_out ]; then
      $nmv aircftbias_out $BIASOAIR
      fi
      if [ $DONST = "YES" ]; then
         $nmv dtfanl $DTFANL 
      fi
  else
      exit 1
  fi
fi
# Loop over first and last outer loops to generate innovation
# diagnostic files for indicated observation types (groups)
#
# NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
#        loop 03 will contain innovations with respect to 
#        the analysis.  Creation of o-a innovation files
#        is triggered by write_diag(3)=.true.  The setting
#        write_diag(1)=.true. turns on creation of o-g
#        innovation files.
#


if [[ "$skipcat" = "false" ]]; then

echo "Time before diagnostic loop is `date` "
if [[ "$HXONLY" = "YES" ]]; then
  loops="01"
else
  if [ $NOOUTERLOOP == "YES" ]; then
     loops="01 02"
  else
     loops="01 03"
  fi
fi

# run each nc_diag_cat on a separate node, concurrently
nodecount=0
# mpi version
#export OMP_NUM_THREADS=1
#export nprocs=$corespernode
# serial version
export nprocs=1
export OMP_NUM_THREADS=$corespernode
export mpitaskspernode=1
totnodes=$NODES
nnode=0
for node in `scontrol show hostnames $SLURM_JOB_NODELIST`; do
    let nnode+=1
    echo "$nnode $node"
done

for loop in $loops; do

   case $loop in
     01) string=ges;;
     02) string=anl;;
     03) string=anl;;
      *) string=$loop;;
   esac
   
   #  Collect diagnostic files for obs types (groups) below
   for type in $alldiag; do
       count=`ls pe*${type}_${loop}* | wc -l`
       if [[ $count -gt 0 ]]; then
          if [[ $count -eq 1 ]]; then
            # just one file, no cat needed (just copy it)
            file=`ls -1 pe*${type}_${loop}*`
            /bin/cp -f $file ${savdir}/diag_${type}_${string}.${adate}_${charnanal2}.nc4
          else
            export PGM="ncdiag_cat_serial.x -o ${savdir}/diag_${type}_${string}.${adate}_${charnanal2}.nc4  pe*${type}_${loop}*nc4"
            ls -l pe*${type}_${loop}*nc4
            nodecount=$((nodecount+1))
            echo "node = $nodecount ${scriptsdir}/runmpi 1> ${current_logdir}/nc_diag_cat_${type}_${string}_${charnanal2}.out"
            ${scriptsdir}/runmpi 1> ${current_logdir}/nc_diag_cat_${type}_${string}_${charnanal2}.out 2> ${current_logdir}/nc_diag_cat_${type}_${string}_${charnanal2}.err &
            #${scriptsdir}/runmpi 1> nc_diag_cat_${type}_${string}.out &
            if [ $nodecount -eq $totnodes ]; then
               echo "waiting... nodecount=$nodecount"
               wait
               nodecount=0
            fi       
          fi
       fi
   done

done

wait
echo "Time after diagnostic loop is `date` "

if [ ! -s $savdir/diag_conv_uv_ges.${adate}_${charnanal2}.nc4 ]; then
   exit 1
fi
if [ ! -s $savdir/diag_conv_t_ges.${adate}_${charnanal2}.nc4 ]; then
   exit 1
fi
if [ ! -s $savdir/diag_conv_q_ges.${adate}_${charnanal2}.nc4 ]; then
   exit 1
fi
if [ ! -s $savdir/diag_conv_ps_ges.${adate}_${charnanal2}.nc4 ]; then
   exit 1
fi

fi # skipcat

# If requested, clean up $tmpdir
if [[ "$CLEAN" = "YES" ]];then
  cd $tmpdir
  cp gsiparm.anl $savdir
  cd ../
  /bin/rm -rf $tmpdir
fi

# End of script
exit 0
