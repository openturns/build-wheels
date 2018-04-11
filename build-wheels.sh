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
${SCRIPTPATH}/install-deps.sh

rm -rf /tmp/openturns
git clone https://github.com/openturns/openturns.git /tmp/openturns
cd /tmp/openturns
git checkout v${VERSION}

mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF -DLINK_PYTHON_LIBRARY=OFF \
      -DPYTHON_INCLUDE_DIR=/opt/python/cp${PYVER}-${ABI}/include/python${PYVERD} \
      -DPYTHON_EXECUTABLE=/opt/python/cp${PYVER}-${ABI}/bin/python ..
make install -j2

# move conf file next to lib so it can be found using dladr when relocated
cp $PWD/install/etc/openturns/openturns.conf $PWD/install/lib

# run a few tests
ctest -R "NLopt|Study|SymbolicFunction|SquareMatrix" -E cppcheck -j2

cd install/lib/python*/site-packages/
rm -rf openturns/__pycache__ openturns/*.pyc

mkdir openturns-${VERSION}.dist-info
cd openturns-${VERSION}.dist-info

echo "Wheel-Version: 1.0" > WHEEL
echo "Generator: custom" >> WHEEL
echo "Root-Is-Purelib: false" >> WHEEL
echo "Tag: ${TAG}" >> WHEEL

cp ${SCRIPTPATH}/METADATA .
cd ..

touch openturns-${VERSION}.dist-info/RECORD
for FILE in `ls openturns/*` `ls openturns-${VERSION}.dist-info/*`
do
  SHA=`sha256sum ${FILE}| cut -d " " -f 1`
  SIZE=`du -k ${FILE}| cut -f1`
  echo "${FILE},sha256=${SHA},${SIZE}" >> openturns-${VERSION}.dist-info/RECORD
done
echo "openturns-${VERSION}.dist-info/RECORD,," >> openturns-${VERSION}.dist-info/RECORD


zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

auditwheel show openturns-${VERSION}-${TAG}.whl
auditwheel repair openturns-${VERSION}-${TAG}.whl -w /io/wheelhouse/

/opt/python/cp${PYVER}-${ABI}/bin/pip install openturns --no-index -f /io/wheelhouse
/opt/python/cp${PYVER}-${ABI}/bin/python -c "import openturns as ot; print(ot.Normal(3).getRealization())"


