# env vars used: datapath2, NODES, NODEFILE, enkfscripts
setenv nprocs 1
setenv mpitaskspernode 1
set nodecount=0
module load nco/4.7.0
foreach id ('ges' 'anl')
   set diagfiles = `ls -1 ${datapath2}/diag*${id}*control.nc4`
   foreach diagfile ($diagfiles)
       echo $diagfile
       set diagfile2=`echo ${diagfile} | sed 's/anl/ges/' | sed 's/control/ensmean/g'`
       setenv PGM "python ${enkfscripts}/copyenkfdata.py $diagfile2 $diagfile $id"
       @ nodecount = $nodecount + 1
       if ($machine == 'theia' ) then
          set node=`head -$nodecount $NODEFILE | tail -1`
          setenv HOSTFILE ${datapath2}/hostfile_${nodecount}
          /bin/rm -f $HOSTFILE
          set n=1
          while ($n <= $nprocs) 
             echo $node >> $HOSTFILE
             @ n = $n + 1
          end
          #echo "contents of hostfile_${nodecount}..."
          #cat $HOSTFILE
       endif
       sh ${enkfscripts}/runmpi &
       if ($nodecount == $NODES ) then
          echo "waiting... nodecount=$nodecount"
          wait
          set nodecount=0
       endif
   end
end
wait
echo "waiting for last run to finish"
exit 0
