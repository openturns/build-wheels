#!/bin/sh

set -x

test $# = 2 || exit 1

GIT_VERSION="$1"
ABI="$2"

PLATFORM="macosx_11_0_`uname -m`"
PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVER=${PYTAG:2:1}.${PYTAG:3}

# setup brew dependencies
brew install --overwrite coreutils openblas swig boost python@${PYVER} tbb nlopt cminpack ceres-solver bison flex hdf5 ipopt primesieve spectra pagmo libxml2
python${PYVER} -m pip install delocate
python${PYVER} -m pip debug --verbose

SCRIPT=`greadlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`

cd /tmp
git clone --depth 1 -b ${GIT_VERSION} https://github.com/openturns/openturns.git
cd openturns
VERSION=`cat VERSION`

#VERSION=${VERSION}.post2
#./utils/setVersionNumber.sh ${VERSION}
#sed -i "s/set (CPACK_PACKAGE_VERSION_PATCH /set (CPACK_PACKAGE_VERSION_PATCH post2/g" CMakeLists.txt

BREWPREFIX=`brew --prefix`
PYPREFIX=`brew --cellar python@${PYVER}`
PYLIB=`find ${PYPREFIX} -name libpython${PYVER}.dylib | grep -v config`
PYINC=`find ${PYPREFIX} -name Python.h | xargs dirname`

mkdir build && cd build
cmake -LAH -DCMAKE_INSTALL_PREFIX=$PWD/install \
      -DPYTHON_EXECUTABLE=${PYPREFIX}/bin/python3 \
      -DPYTHON_LIBRARY=${PYLIB} \
      -DPYTHON_INCLUDE_DIR=${PYINC} \
      -DFLEX_EXECUTABLE=${BREWPREFIX}/opt/flex/bin/flex \
      -DBISON_EXECUTABLE=${BREWPREFIX}/opt/bison/bin/bison \
      -DLIBXML2_LIBRARY=${BREWPREFIX}/opt/libxml2/lib/libxml2.dylib \
      -DLIBXML2_INCLUDE_DIR=${BREWPREFIX}/opt/libxml2/include \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1" \
      -DUSE_SPHINX=OFF \
      ..
make install

# run a few tests
ctest -R "Ipopt|Bonmin|Dlib_std|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres|Sample_csv|Pagmo" -E cppcheck --output-on-failure ${MAKEFLAGS}

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns.libs
cp -v ../../../etc/openturns/openturns.conf openturns.libs

# write metadata
python${PYVER} ${SCRIPTPATH}/write_RECORD.py openturns ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns.libs openturns-${VERSION}.dist-info

# gather dependencies
delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${SCRIPTPATH}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# test
cd /tmp
python${PYVER} -m pip install dill psutil
python${PYVER} -m pip install openturns --pre --no-index -f ${SCRIPTPATH}/wheelhouse -vvv
python${PYVER} -c "import openturns as ot; print(ot.__version__)"
