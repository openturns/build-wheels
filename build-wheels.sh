#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"
PLATFORM="$4"

TAG="cp${PYVER}-${ABI}-${PLATFORM}"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
if test "${ABI: -1}" = "m"
then
  PYVERD=${PYVERD}m
fi

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`

cd /tmp
curl -fSsL https://github.com/openturns/openturns/archive/v${VERSION}.tar.gz | tar xz && cd openturns-${VERSION}

mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF \
      -DPYTHON_INCLUDE_DIR=/opt/python/cp${PYVER}-${ABI}/include/python${PYVERD} \
      -DPYTHON_LIBRARY=/usr/lib64/libpython2.4.so \
      -DPYTHON_EXECUTABLE=/opt/python/cp${PYVER}-${ABI}/bin/python \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1" \
      ..
make install

# run a few tests
ctest -R "Ipopt|Dlib|NLopt|Study|SymbolicFunction|SquareMatrix|CMinpack|Ceres" -E cppcheck ${MAKEFLAGS}

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__

# move conf file next to lib so it can be found using dladr when relocated
mkdir -p openturns.libs
cp ../../../etc/openturns/openturns.conf openturns.libs

# write metadata
/opt/python/cp${PYVER}-${ABI}/bin/python ${SCRIPTPATH}/write_RECORD.py ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns.libs openturns-${VERSION}.dist-info

auditwheel show openturns-${VERSION}-${TAG}.whl
auditwheel repair openturns-${VERSION}-${TAG}.whl -w /io/wheelhouse/

/opt/python/cp${PYVER}-${ABI}/bin/pip install openturns --no-index -f /io/wheelhouse
/opt/python/cp${PYVER}-${ABI}/bin/python -c "import openturns as ot; print(ot.Normal(3).getSample(10))"


