#!/bin/sh

set -e -x

test $# = 2 || exit 1

VERSION="$1"
ABI="$2"

ARCH=x86_64
MINGW_PREFIX=/usr/${ARCH}-w64-mingw32
PLATFORM=win_amd64

PYVER="${ABI:2:2}"
TAG="cp${PYVER}-${ABI}-${PLATFORM}"

cd /tmp
if test "${VERSION}" = "git"
then
  curl -fSsLO https://raw.githubusercontent.com/openturns/openturns/master/VERSION
  VERSION=`cat VERSION`
  git clone --depth 1 https://github.com/openturns/openturns.git openturns-${VERSION}
else
  curl -fSsL https://github.com/openturns/openturns/archive/v${VERSION}.tar.gz | tar xz
fi

cd openturns-${VERSION}
PREFIX=$PWD/install
${ARCH}-w64-mingw32-cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DPYTHON_INCLUDE_DIR=${MINGW_PREFIX}/include/python${PYVER} \
  -DPYTHON_LIBRARY=${MINGW_PREFIX}/lib/libpython${PYVER}.dll.a \
  -DPYTHON_EXECUTABLE=/usr/bin/${ARCH}-w64-mingw32-python${PYVER}-bin \
  -DUSE_SPHINX=OFF \
  -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
  -DSWIG_COMPILE_FLAGS="-O1" \
  .

make install
${ARCH}-w64-mingw32-strip --strip-unneeded ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/*.pyd

cp -v ${PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/
cp -v ${PREFIX}/etc/openturns/*.conf ${PREFIX}/Lib/site-packages/openturns/
cp -v ${MINGW_PREFIX}/bin/*.dll ${PREFIX}/Lib/site-packages/openturns/
rm ${PREFIX}/Lib/site-packages/openturns/libboost*.dll ${PREFIX}/Lib/site-packages/openturns/python*.dll

cd ${PREFIX}/Lib/site-packages/

# write metadata
python /io/write_RECORD.py openturns ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

# copy to host
sudo mkdir -p /io/wheelhouse
sudo cp -v openturns-${VERSION}-${TAG}.whl /io/wheelhouse/
