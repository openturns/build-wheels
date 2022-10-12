#!/bin/sh

set -e -x

test $# = 2 || exit 1

GIT_VERSION="$1"
ABI="$2"

PLATFORM=manylinux2014_x86_64
PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVERD=${ABI:2:1}.${ABI:3}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp
git clone --depth 1 -b ${GIT_VERSION} https://github.com/openturns/openturns.git
cd openturns
VERSION=`cat VERSION`

#mv openturns-${VERSION} openturns-${VERSION}.post2
#VERSION=${VERSION}.post2
#./utils/setVersionNumber.sh ${VERSION}
#sed -i "s/set (CPACK_PACKAGE_VERSION_PATCH /set (CPACK_PACKAGE_VERSION_PATCH post2/g" CMakeLists.txt
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
ctest -R "Ipopt|Bonmin|Dlib_std|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres|Sample_csv|Pagmo" -E cppcheck --output-on-failure ${MAKEFLAGS}

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
unzip /io/wheelhouse/openturns-${VERSION}-${TAG}.manylinux_2_17_x86_64.whl
readelf -d openturns.libs/libOT-*.so*
NEW_LIBOT=`basename openturns.libs/libOT-*.so*`
cd -

# modules
for pkgnamever in otfftw-0.12 otmixmod-0.13 otmorris-0.13 otpmml-1.12 otrobopt-0.11 otsubsetinverse-1.9 otsvm-0.11
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  git clone --depth 1 -b v${pkgver} https://github.com/openturns/${pkgname}.git && cd ${pkgname}
  pkgver=${pkgver}.post3
  ./setVersionNumber.sh ${pkgver}
  mkdir build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF -DBUILD_DOC=OFF \
        -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
        -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
        -DOpenTURNS_DIR=/tmp/openturns/build/install/lib/cmake/openturns \
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