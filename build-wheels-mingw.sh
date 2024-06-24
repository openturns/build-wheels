#!/bin/sh

set -e -x

test $# = 3 || exit 1

REPO="$1"
GIT_VERSION="$2"
ABI="$3"

ARCH=x86_64
MINGW_PREFIX=/usr/${ARCH}-w64-mingw32
PLATFORM=win_amd64

PYTAG=${ABI/m/}
PYVER=${PYTAG:2}
TAG=${PYTAG}-${ABI}-${PLATFORM}

cd /tmp
git clone --depth 1 -b ${GIT_VERSION} https://github.com/${REPO}/openturns.git
cd openturns
VERSION=`cat VERSION`

PREFIX=$PWD/install
${ARCH}-w64-mingw32-cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DPython_INCLUDE_DIR=${MINGW_PREFIX}/include/python${PYVER} \
  -DPython_LIBRARY=${MINGW_PREFIX}/lib/libpython${PYVER}.dll.a \
  -DPython_EXECUTABLE=/usr/bin/${ARCH}-w64-mingw32-python${PYVER}-bin \
  -DUSE_SPHINX=OFF \
  -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
  -DSWIG_COMPILE_FLAGS="-O1" \
  .

make install
${ARCH}-w64-mingw32-strip --strip-unneeded ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/*.pyd

cp -v ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/
cp -v ${PREFIX}/etc/openturns/*.conf ${PREFIX}/Lib/site-packages/openturns/
cp -v ${MINGW_PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/
rm ${PREFIX}/Lib/site-packages/openturns/{libboost,python,libgraphblas}*.dll

cd ${PREFIX}/Lib/site-packages/

# write metadata
python /io/write_distinfo.py openturns ${VERSION} ${TAG}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

# copy to host
sudo mkdir -p /io/wheelhouse
sudo cp -v openturns-${VERSION}-${TAG}.whl /io/wheelhouse/

grep -q dev <<< "${VERSION}" && exit 0

aurman -S mingw-w64-fftw mingw-w64-agrum mingw-w64-libmixmod --noconfirm --noedit --pgp_fetch

# modules
for pkgnamever in otfftw-0.15 otmixmod-0.17 otmorris-0.16 otrobopt-0.14 otsvm-0.14
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  git clone --depth 1 -b v${pkgver} https://github.com/openturns/${pkgname}.git && cd ${pkgname}
  sed -i "s|Metadata-Version: 2.0|Metadata-Version: 1.2|g" python/src/METADATA.in
  pkgver=${pkgver}.post1
  ./utils/setVersionNumber.sh ${pkgver}
  PREFIX=$PWD/install
  ${ARCH}-w64-mingw32-cmake \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCMAKE_UNITY_BUILD=ON \
    -DPython_INCLUDE_DIR=${MINGW_PREFIX}/include/python${PYVER} \
    -DPython_LIBRARY=${MINGW_PREFIX}/lib/libpython${PYVER}.dll.a \
    -DPython_EXECUTABLE=/usr/bin/${ARCH}-w64-mingw32-python${PYVER}-bin \
    -DUSE_SPHINX=OFF -DBUILD_DOC=OFF \
    -DOpenTURNS_DIR=/tmp/openturns/install/lib/cmake/openturns \
    .
  make install
  ${ARCH}-w64-mingw32-strip --strip-unneeded ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/${pkgname}/*.pyd
  cp -v ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/${pkgname}
  if test "${pkgname}" = "otfftw"; then cp -v ${MINGW_PREFIX}/bin/libfftw*.dll ${PREFIX}/Lib/site-packages/${pkgname}; fi
  if test "${pkgname}" = "otagrum"; then cp -v ${MINGW_PREFIX}/bin/libagrum.dll ${PREFIX}/Lib/site-packages/${pkgname}; fi
  if test "${pkgname}" = "otmixmod"; then cp -v ${MINGW_PREFIX}/bin/libmixmod.dll ${PREFIX}/Lib/site-packages/${pkgname}; fi
  cd ${PREFIX}/Lib/site-packages

  # write metadata
  python /io/write_distinfo.py ${pkgname} ${pkgver} ${TAG}

  zip -r ${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}-${pkgver}.dist-info
  sudo cp -v ${pkgname}-${pkgver}-${TAG}.whl /io/wheelhouse/
done
