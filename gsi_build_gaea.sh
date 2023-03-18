#!/bin/bash

set -ux

# Get the root of the cloned GSI directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# User Options
BUILD_TYPE=${BUILD_TYPE:-"Release"}
CMAKE_OPTS=${CMAKE_OPTS:-}
COMPILER=${COMPILER:-"intel"}
BUILD_DIR=${BUILD_DIR:-"${DIR_ROOT}/build"}
INSTALL_PREFIX=${INSTALL_PREFIX:-"${DIR_ROOT}/install"}
GSI_MODE=${GSI_MODE:-"Regional"}  # By default build Regional GSI (for regression testing)
ENKF_MODE=${ENKF_MODE:-"GFS"}     # By default build Global EnKF  (for regression testing)
REGRESSION_TESTS=${REGRESSION_TESTS:-"YES"} # Build regression test suite

#==============================================================================#

# Detect machine (sets MACHINE_ID)
source $DIR_ROOT/ush/detect_machine.sh

# Load modules
set +x
#source $DIR_ROOT/ush/module-setup.sh

source /lustre/f2/dev/role.epic/contrib/Lmod_init.sh
module unload cray-libsci
module purge

export _LMFILES_=""
export LOADEDMODULES=""
module load PrgEnv-intel
module load intel/2021.3.0
module load cray-mpich/7.7.11
module use -a /lustre/f2/dev/role.epic/contrib/modulefiles
module load miniconda3
module load cmake
module use -a /lustre/f2/dev/role.epic/contrib/hpc-stack/intel-2021.3.0_noarch/modulefiles/stack
#module use -a /lustre/f2/pdata/ncep_shared/hpc-stack/modulefiles/stack # no ncdiag?
module load hpc/1.2.0
module load hpc-intel/2021.3.0
module load hpc-cray-mpich/7.7.11
module load bufr
module load bacio
module load w3emc/2.9.2
module load sp
module load ip
module load sigio
module load sfcio
module load nemsio/2.5.4
module load wrf_io
module load ncio
module load crtm/2.3.0
module load ncdiag
module load netcdf

export GSI_BINARY_SOURCE_DIR=$DIR_ROOT/fix
export CC=cc
export CXX=CC
export FC="ftn -mkl=sequential"
export CMAKE_C_COMPILER=cc
export CMAKE_CXX_COMPILER=CC
export CMAKE_Fortran_COMPILER="ftn -mkl=sequential"
export MKLROOT=/opt/intel/oneapi/mkl/2022.0.2
#source  /opt/intel/oneapi/setvars.sh intel64 
#module use $DIR_ROOT/modulefiles
#module load gsi_$MACHINE_ID
module list

set -x

# Set CONTROLPATH variable to user develop installation
CONTROLPATH="$DIR_ROOT/../develop/install/bin"

# Collect BUILD Options
CMAKE_OPTS+=" -DCMAKE_BUILD_TYPE=$BUILD_TYPE"

# Install destination for built executables, libraries, CMake Package config
CMAKE_OPTS+=" -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX"

# Configure for GSI and EnKF
CMAKE_OPTS+=" -DGSI_MODE=$GSI_MODE -DENKF_MODE=${ENKF_MODE} -DENABLE_MKL=ON"

# Build regression test suite (on supported MACHINE_ID where CONTROLPATH exists)
[[ ${REGRESSION_TESTS} =~ [yYtT] ]] && CMAKE_OPTS+=" -DBUILD_REG_TESTING=ON -DCONTROLPATH=${CONTROLPATH:-}"

# Re-use or create a new BUILD_DIR (Default: create new BUILD_DIR)
[[ ${BUILD_CLEAN:-"YES"} =~ [yYtT] ]] && rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR && cd $BUILD_DIR

# Configure, build, install
cmake $CMAKE_OPTS $DIR_ROOT
make -j ${BUILD_JOBS:-8} VERBOSE=${BUILD_VERBOSE:-}
make install

exit
