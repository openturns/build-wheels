#!/bin/sh

set -e -x

test $# = 2 || exit 1

REPO="$1"
GIT_VERSION="$2"

env
uname -a
ARCH=`uname -m`
SDK_MAJOR=`sw_vers -productVersion | cut -d '.' -f 1`

# this should reflect the CI image being used
PLATFORM="macosx_${SDK_MAJOR}_0_${ARCH}"
ABI=cp39
PYTAG=${ABI/m/}
TAG=${PYTAG}-abi3-${PLATFORM}
PYVER=${PYTAG:2:1}.${PYTAG:3}

# setup brew dependencies
brew install --overwrite coreutils openblas swig boost python@${PYVER} tbb nlopt cminpack ceres-solver hdf5 ipopt primesieve spectra pagmo libxml2 nanoflann cuba
export PATH=/Library/Frameworks/Python.framework/Versions/${PYVER}/bin:$PATH
python${PYVER} -m pip install delocate --break-system-packages
python${PYVER} -m pip debug --verbose

SCRIPT=`greadlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`

cd /tmp
git clone --depth 1 -b ${GIT_VERSION} https://github.com/${REPO}/openturns.git
cd openturns
git diff
VERSION=`cat VERSION`

#VERSION=${VERSION}.post2
#./utils/setVersionNumber.sh ${VERSION}

BREWPREFIX=`brew --prefix`
PYPREFIX=`brew --cellar python@${PYVER}`
PYINC=`find ${PYPREFIX} -name Python.h | xargs dirname`

cmake -LAH -DCMAKE_INSTALL_PREFIX=$PWD/build/install \
      -DPython_EXECUTABLE=${BREWPREFIX}/bin/python${PYVER} \
      -DPython_INCLUDE_DIR=${PYINC} \
      -DLIBXML2_LIBRARY=${BREWPREFIX}/opt/libxml2/lib/libxml2.dylib \
      -DLIBXML2_INCLUDE_DIR=${BREWPREFIX}/opt/libxml2/include \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1 -DPy_LIMITED_API=0x03090000" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=${SDK_MAJOR}.0 \
      -B build .
cd build
make install

# run a few tests
ctest -R "Ipopt|Bonmin|Dlib_std|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres|Sequence|Mesh_std|Pagmo|Cuba|KDTree" -E cppcheck --output-on-failure ${MAKEFLAGS}

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__

# write metadata
python${PYVER} ${SCRIPTPATH}/write_distinfo.py openturns ${VERSION} ${TAG}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

# gather dependencies
delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${SCRIPTPATH}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns/.dylibs
cp -v ../../../etc/openturns/openturns.conf openturns/.dylibs
zip ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/openturns.conf

# test
cd /tmp
python${PYVER} -m pip install dill psutil --break-system-packages
python${PYVER} -m pip install openturns --pre --no-index -f ${SCRIPTPATH}/wheelhouse -vvv --break-system-packages
python${PYVER} -c "import openturns as ot; print(ot.__version__)"

grep -q dev <<< "${VERSION}" && exit 0

# modules
for pkgnamever in otmorris-0.18 otrobopt-0.16 otsvm-0.16
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  git clone --depth 1 -b v${pkgver} https://github.com/openturns/${pkgname}.git && cd ${pkgname}
  pkgver=${pkgver}.post1
  curl -o utils/setVersionNumber.sh https://raw.githubusercontent.com/openturns/ottemplate/refs/heads/master/utils/setVersionNumber.sh
  ./utils/setVersionNumber.sh ${pkgver}
  cmake -LAH -DCMAKE_INSTALL_PREFIX=$PWD/build/install \
        -DCMAKE_UNITY_BUILD=ON \
        -DSWIG_COMPILE_FLAGS="-O1 -DPy_LIMITED_API=0x03090000" \
        -DPython_EXECUTABLE=${BREWPREFIX}/bin/python${PYVER} \
        -DPython_LIBRARY=${PYLIB} \
        -DPython_INCLUDE_DIR=${PYINC} \
        -DOpenTURNS_DIR=/tmp/openturns/build/install/lib/cmake/openturns \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=${SDK_MAJOR}.0 \
        -B build .
  cd build
  make install
  ctest -E cppcheck --output-on-failure ${MAKEFLAGS}

  cd install/lib/python*/site-packages/
  rm -rf ${pkgname}/__pycache__

  # copy libs
  mkdir ${pkgname}/.dylibs
  cp -v ../../lib${pkgname}.0.dylib ${pkgname}/.dylibs
  install_name_tool -change @rpath/libOT.0.26.dylib @loader_path/../../openturns/.dylibs/libOT.0.26.0.dylib ${pkgname}/.dylibs/lib${pkgname}.0.dylib
  install_name_tool -delete_rpath /tmp/openturns/build/install/lib ${pkgname}/.dylibs/lib${pkgname}.0.dylib
  install_name_tool -delete_rpath /tmp/${pkgname}/build/install/lib ${pkgname}/.dylibs/lib${pkgname}.0.dylib
  otool -l ${pkgname}/.dylibs/lib${pkgname}.0.dylib
  install_name_tool -change @rpath/libOT.0.26.dylib @loader_path/../openturns/.dylibs/libOT.0.26.0.dylib ${pkgname}/_${pkgname}.so
  install_name_tool -change @rpath/lib${pkgname}.0.dylib @loader_path/.dylibs/lib${pkgname}.0.dylib ${pkgname}/_${pkgname}.so
  install_name_tool -delete_rpath /tmp/openturns/build/install/lib ${pkgname}/_${pkgname}.so
  install_name_tool -delete_rpath /tmp/${pkgname}/build/install/lib ${pkgname}/_${pkgname}.so
  otool -l ${pkgname}/_${pkgname}.so

  # write metadata
  python${PYVER} ${SCRIPTPATH}/write_distinfo.py ${pkgname} ${pkgver} ${TAG}

  # create archive
  zip -r ${SCRIPTPATH}/wheelhouse/${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}-${pkgver}.dist-info

  # test
  cd /tmp
  python${PYVER} -m pip install ${pkgname} --pre --no-index -f ${SCRIPTPATH}/wheelhouse -vvv --break-system-packages
  python${PYVER} -c "import ${pkgname}; print(${pkgname}.__version__)"
done
