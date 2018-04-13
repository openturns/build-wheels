#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"

TAG="cp${PYVER}-${ABI}-manylinux1_x86_64"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
if test "${PYVER:0:1}" = "3"
then
  PYVERD=${PYVERD}m
fi

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`

rm -rf /tmp/openturns
git clone https://github.com/openturns/openturns.git /tmp/openturns
cd /tmp/openturns
git checkout v${VERSION}

mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF -DLINK_PYTHON_LIBRARY=OFF \
      -DPYTHON_INCLUDE_DIR=/opt/python/cp${PYVER}-${ABI}/include/python${PYVERD} \
      -DPYTHON_EXECUTABLE=/opt/python/cp${PYVER}-${ABI}/bin/python ..
make install -j2

# run a few tests
ctest -R "NLopt|Study|SymbolicFunction|SquareMatrix" -E cppcheck -j2

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__ openturns/*.pyc

# move conf file next to lib so it can be found using dladr when relocated
mkdir -p openturns/.libs
cp ../../../etc/openturns/openturns.conf openturns/.libs

# write metadata
mkdir openturns-${VERSION}.dist-info
cp ${SCRIPTPATH}/METADATA openturns-${VERSION}.dist-info
/opt/python/cp${PYVER}-${ABI}/bin/python ${SCRIPTPATH}/write_WHEEL.py ${VERSION} ${TAG}
/opt/python/cp${PYVER}-${ABI}/bin/python ${SCRIPTPATH}/write_RECORD.py ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

auditwheel show openturns-${VERSION}-${TAG}.whl
auditwheel repair openturns-${VERSION}-${TAG}.whl -w /io/wheelhouse/

/opt/python/cp${PYVER}-${ABI}/bin/pip install openturns --no-index -f /io/wheelhouse
/opt/python/cp${PYVER}-${ABI}/bin/python -c "import openturns as ot; print(ot.Normal(3).getRealization())"


