#!/bin/sh

set -e -x

test $# = 3 || exit 1

VERSION="$1"
ABI="$2"
PLATFORM="$3"

PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVERD=${ABI:2:1}.${ABI:3}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp
if test "${VERSION}" = "git"
then
  curl -fSsLO https://raw.githubusercontent.com/openturns/openturns/master/VERSION
  VERSION=`cat VERSION`
  git clone --depth 1 https://github.com/openturns/openturns.git openturns-${VERSION}
else
  curl -fSsL https://github.com/openturns/openturns/archive/v${VERSION}.tar.gz | tar xz
fi

mv openturns-${VERSION} openturns-${VERSION}.post1
VERSION=${VERSION}.post1
cd openturns-${VERSION}
./utils/setVersionNumber.sh ${VERSION}
sed -i "s/set (CPACK_PACKAGE_VERSION_PATCH /set (CPACK_PACKAGE_VERSION_PATCH post1/g" CMakeLists.txt
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF \
      -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
      -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1" \
      ..
make install
OLD_LIBOT=`basename install/lib/libOT.so.0.*`

# run a few tests
ctest -R "Ipopt|Bonmin|Dlib_std|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres|Sample_csv" -E cppcheck --output-on-failure ${MAKEFLAGS}

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns.libs
cp -v ../../../etc/openturns/openturns.conf openturns.libs

# write metadata
python ${SCRIPTPATH}/write_RECORD.py openturns ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns.libs openturns-${VERSION}.dist-info

auditwheel show openturns-${VERSION}-${TAG}.whl
auditwheel repair openturns-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip install dill psutil
pip install openturns --pre --no-index -f /io/wheelhouse
python -c "import openturns as ot; print(ot.__version__)"

grep -q dev <<< "${VERSION}" && exit 0

# lookup new OT lib name
unzip /io/wheelhouse/openturns-${VERSION}-${TAG}.manylinux_2_5_x86_64.whl
readelf -d openturns.libs/libOT-*.so*
NEW_LIBOT=`basename openturns.libs/libOT-*.so*`
cd -

# modules
for pkgnamever in otfftw-0.11 otmixmod-0.12 otmorris-0.11 otpmml-1.11 otrobopt-0.9 otsubsetinverse-1.8 otsvm-0.10
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  curl -fSsL https://github.com/openturns/${pkgname}/archive/v${pkgver}.tar.gz | tar xz && cd ${pkgname}-${pkgver}
  pkgver=${pkgver}.post1
  ./setVersionNumber.sh ${pkgver}
  mkdir build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF -DBUILD_DOC=OFF \
        -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
        -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
        -DOpenTURNS_DIR=/tmp/openturns-${VERSION}/build/install/lib/cmake/openturns \
        ..
  make install
  ctest -E cppcheck --output-on-failure ${MAKEFLAGS}

  cd install/lib/python*/site-packages/
  rm -rf ${pkgname}/__pycache__

  # write metadata
  python ${SCRIPTPATH}/write_RECORD.py ${pkgname} ${pkgver}

  # copy libs
  mkdir ${pkgname}.libs
  cp -v ../../lib${pkgname}.so.0 ${pkgname}.libs
  if test "${pkgname}" = "otfftw"; then cp -v /usr/local/lib/libfftw3.so.3 otfftw.libs; fi

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
