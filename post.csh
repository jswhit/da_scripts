module load grib_util/1.0.3
setenv WORKDIR $DATOUT
echo "WORKDIR = $WORKDIR"

cd $WORKDIR
set fhr=0
while ($fhr <= $FHMAX) 
set charfhr=`printf %02i $fhr`
setenv NEMSINP $WORKDIR/sfg_${analdatep1}_fhr${charfhr}_${charnanal}
setenv FLXINP $WORKDIR/bfg_${analdatep1}_fhr${charfhr}_${charnanal}
echo "NEMSINP = $NEMSINP"
echo "FLXINP = $FLXINP"

setenv FLXIOUT $WORKDIR/bfg_${analdatep1}_fhr${charfhr}_${charnanal}.idx
setenv PGBOUT $WORKDIR/pgrb.${analdate}.fhr${charfhr}
setenv OUTTYP 4

setenv EXECUTIL /gpfs/hps/nco/ops/nwprod/grib_util.v1.0.3/exec
setenv EMCglobal /gpfs/hps3/emc/global/noscrub/emc.glopara/svn/gfs/q3fy17_final/global_shared.v14.1.0
setenv USHglobal  ${EMCglobal}/ush
setenv FIXglobal  ${EMCglobal}/fix
setenv EXECglobal ${EMCglobal}/exec
setenv POSTGPEXEC  ${EXECglobal}/ncep_post
setenv nemsioget   ${EXECglobal}/nemsio_get

setenv PARMglobal ${enkfscripts}
## setenv PARMglobal ${EMCglobal}/parm
setenv CTLFILE $PARMglobal/gfs_cntrl.parm

setenv APRUN "aprun -n $nprocs"
setenv VERBOSE "YES"

set incdate=${enkfscripts}/incdate.sh
## set incdate=/u/Jeffrey.S.Whitaker/bin/incdate
## set idate=`$nemsioget $NEMSINP idate | tail -1 | cut -f2 -d"="`
## set fhr=`$nemsioget $NEMSINP nfhour | cut -f2 -d"="`
setenv VDATE `${incdate} $analdate $fhr`

setenv MODEL_OUT_FORM binarynemsio
setenv LONB `$nemsioget $NEMSINP dimx |grep -i "dimx" |awk -F"= " '{print $2}' |awk -F" " '{print $1}'`
setenv LATB `$nemsioget $NEMSINP dimy |grep -i "dimy" |awk -F"= " '{print $2}' |awk -F" " '{print $1}'`
setenv POSTGPVARS "KPO=16,PO=1000.,925.,850.,800.,750.,700.,600.,500.,400.,300.,250.,200.,150.,100.,50.,10.,"
setenv OMP_NUM_THREADS 1
setenv OMP_STACKSIZE 256M

sh ${enkfscripts}/global_nceppost.sh

@ fhr = $fhr + $FHOUT
end
