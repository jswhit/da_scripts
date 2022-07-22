/bin/rm -rf ufs-weather-model-p8c-atm
git clone https://github.com/ufs-community/ufs-weather-model ufs-weather-model-p8c-atm
cd ufs-weather-model-p8c-atm
git checkout Prototype-P8c
git submodule update --init --recursive
# add no nsst version of p8 suite
/bin/cp -f /scratch2/BMC/gsienkf/whitaker/suite_FV3_GFS_v17_p8_nonsst.xml FV3/ccpp/suites
cd tests
./compile.sh hera.intel "-DAPP=ATM -D32BIT=ON -DCCPP_SUITES=FV3_GFS_v16,FV3_GFS_v16_no_nsst,FV3_GFS_v17_p8,FV3_GFS_v17_p8_nonsst" atm YES NO
