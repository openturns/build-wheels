#!/bin/sh

set -e -x

test $# = 2 || exit 1

REPO="$1"
GIT_VERSION="$2"

ABI=cp39
ARCH=`uname -m`
PLATFORM=manylinux2014_${ARCH}
PYTAG=${ABI/m/}
TAG=${PYTAG}-abi3-${PLATFORM}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp
git clone --depth 1 -b ${GIT_VERSION} https://github.com/${REPO}/openturns.git
cd openturns
VERSION=`cat VERSION`

#mv openturns-${VERSION} openturns-${VERSION}.post2
#VERSION=${VERSION}.post2
#./utils/setVersionNumber.sh ${VERSION}

cmake -DCMAKE_INSTALL_PREFIX=$PWD/build/install \
      -DPython_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1 -DPy_LIMITED_API=0x03090000"  \
      -B build .
cd build
make install
OLD_LIBOT=`basename install/lib64/libOT.so.0.*`

# run a few tests
ctest -R "Ipopt|Bonmin|Dlib_std|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres|Sequence|Mesh_std|Pagmo|Cuba|KDTree" -E cppcheck --output-on-failure ${MAKEFLAGS}

cd install/lib*/python*/site-packages/
rm -rf openturns/__pycache__

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns.libs
cp -v ../../../etc/openturns/openturns.conf openturns.libs

# write metadata
python ${SCRIPTPATH}/write_distinfo.py openturns ${VERSION} ${TAG}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns.libs openturns-${VERSION}.dist-info

auditwheel show openturns-${VERSION}-${TAG}.whl
auditwheel repair openturns-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
export PIP_ROOT_USER_ACTION=ignore
pip install dill psutil
pip install openturns --pre --no-index -f /io/wheelhouse
python -c "import openturns as ot; print(ot.__version__)"

pip install abi3audit
abi3audit /io/wheelhouse/openturns-${VERSION}-${TAG}.manylinux*.whl --verbose --summary --assume-minimum-abi3 3.9

grep -q dev <<< "${VERSION}" && exit 0

# lookup new OT lib name
unzip /io/wheelhouse/openturns-${VERSION}-${TAG}.manylinux*.whl
readelf -d openturns.libs/libOT-*.so*
NEW_LIBOT=`basename openturns.libs/libOT-*.so*`
cd -

# modules
for pkgnamever in otfftw-0.17 otmixmod-0.19 otmorris-0.18 otrobopt-0.16 otsvm-0.16
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  git clone --depth 1 -b v${pkgver} https://github.com/openturns/${pkgname}.git && cd ${pkgname}
  # pkgver=${pkgver}.post1
  # ./utils/setVersionNumber.sh ${pkgver}
  cmake -DCMAKE_INSTALL_PREFIX=$PWD/build/install -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_UNITY_BUILD=ON \
        -DSWIG_COMPILE_FLAGS="-O1 -DPy_LIMITED_API=0x03090000" \
        -DPython_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
        -DOpenTURNS_DIR=/tmp/openturns/build/install/lib64/cmake/openturns \
        -B build .
  cd build
  make install
  ctest -E cppcheck --output-on-failure ${MAKEFLAGS}

  cd install/lib*/python*/site-packages/
  rm -rf ${pkgname}/__pycache__

  # write metadata
  python ${SCRIPTPATH}/write_distinfo.py ${pkgname} ${pkgver} ${TAG}

  # copy libs
  mkdir ${pkgname}.libs
  cp -v ../../lib${pkgname}.so.0 ${pkgname}.libs
  if test "${pkgname}" = "otfftw"; then cp -v /usr/local/lib/libfftw3.so.3 otfftw.libs; fi
  if test "${pkgname}" = "otmixmod"; then cp -v /usr/local/lib*/libmixmod.so.* otmixmod.libs; fi

  # relink
  patchelf --remove-rpath ${pkgname}.libs/lib${pkgname}.so.0 ${pkgname}/_${pkgname}.so
  patchelf --force-rpath --set-rpath "\$ORIGIN/../${pkgname}.libs:\$ORIGIN/../openturns.libs" ${pkgname}.libs/lib${pkgname}.so.0 ${pkgname}/_${pkgname}.so
  patchelf --print-rpath ${pkgname}.libs/lib${pkgname}.so.0 ${pkgname}/_${pkgname}.so
  patchelf --replace-needed ${OLD_LIBOT} ${NEW_LIBOT} ${pkgname}.libs/lib${pkgname}.so.0 ${pkgname}/_${pkgname}.so

  # create archive
  zip -r /io/wheelhouse/${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}.libs ${pkgname}-${pkgver}.dist-info

  # test
  cd /tmp
  pip install ${pkgname} --pre --no-index -f /io/wheelhouse
  python -c "import ${pkgname}; print(${pkgname}.__version__)"
done
