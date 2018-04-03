# env vars needed: HXONLY, machine, corespernode, NODES, execdir, analdate, charnanal, NODEFILE

satdiag="ssu_n14 hirs2_n14 msu_n14 sndr_g08 sndr_g09 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 sndrd1_g14 sndrd2_g14 sndrd3_g14 sndrd4_g14 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 hirs2_n14 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 imgr_g14 imgr_g15 gome_metop-a omi_aura mls_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a amsua_n18 amsua_metop-a mhs_n18 mhs_metop-a amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 ssmis_las_f17 ssmis_uas_f17 ssmis_img_f17 ssmis_env_f17 ssmis_las_f18 ssmis_uas_f18 ssmis_img_f18 ssmis_env_f18 ssmis_las_f19 ssmis_uas_f19 ssmis_img_f19 ssmis_env_f19 ssmis_las_f20 ssmis_uas_f20 ssmis_img_f20 ssmis_env_f20 iasi_metop-a hirs4_n19 amsua_n19 mhs_n19 seviri_m08 seviri_m09 seviri_m10 cris_npp atms_npp hirs4_metop-b amsua_metop-b mhs_metop-b iasi_metop-b gome_metop-b"
alldiag="$satdiag pcp_ssmi_dmsp pcp_tmi_trmm conv_gps conv_t conv_q conv_uv conv_ps sbuv2_n11 sbuv2_n14 sbuv2_n16 sbuv2_n17 sbuv2_n18 sbuv2_n19"

echo "Time before nc_diag_cat loop is `date` "
if [[ "$HXONLY" = "YES" ]]; then
  loops="01"
else
  loops="01 03"
fi

# run each nc_diag_cat on a separate node, concurrently
nodecount=0
export nprocs=$corespernode
export OMP_NUM_THREADS=1
totnodes=$NODES
for loop in $loops; do

   case $loop in
     01) string=ges;;
     03) string=anl;;
      *) string=$loop;;
   esac
   
   #  Collect diagnostic files for obs types (groups) below
   for type in $alldiag; do
       count=`ls pe*${type}_${loop}* | wc -l`
       if [[ $count -gt 0 ]]; then
          export PGM="${execdir}/nc_diag_cat.x -o ${savdir}/diag_${type}_${string}.${analdate}_${charnanal2}.nc4  pe*${type}_${loop}*nc4"
          ls -l pe*${type}_${loop}*nc4
          nodecount=$((nodecount+1))
          if [ "$machine" == 'theia' ]; then
             node=`head -$nodecount $NODEFILE | tail -1`
             export HOSTFILE=hostfile_${nodecount}
             /bin/rm -f $HOSTFILE
             n=1
             while [ $n -le $nprocs ]; do
                echo $node >> $HOSTFILE
                n=$((n+1))
             done
             echo "contents of hostfile_${nodecount}..."
             cat $HOSTFILE
          fi
          #sh ${enkfscripts}/runmpi 1> ${current_logdir}/nc_diag_cat_${type}_${string}_${charnanal2}.out 2> ${current_logdir}/nc_diag_cat_${type}_${string}_${charnanal2}.err &
          sh ${enkfscripts}/runmpi 
          if [ $nodecount -eq $totnodes ]; then
             echo "waiting... nodecount=$nodecount"
             wait
             nodecount=0
          fi       
       fi
   done

done
wait
echo "Time after nc_diag_cat loop is `date` "
