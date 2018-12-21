#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"
PLATFORM="$4"

TAG="cp${PYVER}-${ABI}-${PLATFORM}"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
# if test "${PYVER:0:1}" = "3"
# then
#   PYVERD=${PYVERD}m
# fi

# SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
SCRIPTPATH=${TRAVIS_BUILD_DIR}

wget --no-check-certificate https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -P /tmp
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
conda config --add channels conda-forge
conda install -y python=${PYVERD} cmake swig muparser openblas bison flex nlopt libxml2 tbb-devel pip

rm -rf /tmp/openturns
git clone https://github.com/openturns/openturns.git /tmp/openturns
cd /tmp/openturns
git checkout v${VERSION}

# python_executable=`find /usr/local/Cellar/python/${PYVERD:0:3}* -name python`

mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install \
      -DCMAKE_PREFIX_PATH=${HOME}/miniconda \
      -DCMAKE_INSTALL_RPATH="${HOME}/miniconda/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DCMAKE_MACOSX_RPATH=ON \
      -DLAPACK_LIBRARIES="${HOME}/miniconda/lib/libopenblas.dylib" \
      -DUSE_COTIRE=ON -DCOTIRE_MAXIMUM_NUMBER_OF_UNITY_INCLUDES="-j8" \
      -DSWIG_COMPILE_FLAGS="-O1" \
      ..
make install -j2
otool -L /tmp/openturns/build/install/lib/python${PYVERD:0:3}/site-packages/openturns/_common.so

# run a few tests
ctest -R "NLopt|Study|SymbolicFunction|SquareMatrix" -E cppcheck -j2 --output-on-failure

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__ openturns/*.pyc

# move conf file next to lib so it can be found using dladr when relocated
mkdir -p openturns/.libs
cp ../../../etc/openturns/openturns.conf openturns/.libs

# write metadata
mkdir openturns-${VERSION}.dist-info
cp ${SCRIPTPATH}/METADATA openturns-${VERSION}.dist-info
python ${SCRIPTPATH}/write_WHEEL.py ${VERSION} ${TAG}
python ${SCRIPTPATH}/write_RECORD.py ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

pip install delocate
delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${TRAVIS_BUILD_DIR}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl

pip install openturns --no-index -f ${TRAVIS_BUILD_DIR}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"
