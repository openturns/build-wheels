#!/bin/sh

set -e -x

test $# = 4 || exit 1

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
export PATH=/opt/python/cp${PYVER}-${ABI}/bin/:$PATH

cd /tmp
curl -fSsL https://github.com/openturns/openturns/archive/v${VERSION}.tar.gz | tar xz && cd openturns-${VERSION}

mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF \
      -DPYTHON_INCLUDE_DIR=/opt/python/cp${PYVER}-${ABI}/include/python${PYVERD} \
      -DPYTHON_LIBRARY=/usr/lib64/libpython2.4.so \
      -DPYTHON_EXECUTABLE=/opt/python/cp${PYVER}-${ABI}/bin/python \
      -DCMAKE_UNITY_BUILD=ON -DCMAKE_UNITY_BUILD_BATCH_SIZE=32 \
      -DSWIG_COMPILE_FLAGS="-O1" \
      -DCMINPACK_LIBRARIES="cminpack::cminpack" \
      ..
make install

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
pip install openturns --no-index -f /io/wheelhouse
python -c "import openturns as ot; print(ot.__version__)"

# otagrum-0.3
for pkgnamever in otfftw-0.10 otmixmod-0.11 otmorris-0.9 otpmml-1.10 otrobopt-0.8 otsubsetinverse-1.7 otsvm-0.9
do
  pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
  pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
  cd /tmp
  curl -fSsL https://github.com/openturns/${pkgname}/archive/v${pkgver}.tar.gz | tar xz && cd ${pkgname}-${pkgver}
  mkdir build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_SPHINX=OFF -DBUILD_DOC=OFF \
        -DPYTHON_INCLUDE_DIR=/opt/python/cp${PYVER}-${ABI}/include/python${PYVERD} \
        -DPYTHON_LIBRARY=/usr/lib64/libpython2.4.so \
        -DPYTHON_EXECUTABLE=/opt/python/cp${PYVER}-${ABI}/bin/python \
        -DOpenTURNS_DIR=/tmp/openturns-${VERSION}/build/install/lib/cmake/openturns \
        ..
  make install
  ctest -E cppcheck --output-on-failure ${MAKEFLAGS}

  cd install/lib/python*/site-packages/
  rm -rf ${pkgname}/__pycache__

  # write metadata
  python ${SCRIPTPATH}/write_RECORD.py ${pkgname} ${pkgver}

  # create archive
  zip -r ${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}-${pkgver}.dist-info

  auditwheel show ${pkgname}-${pkgver}-${TAG}.whl
  auditwheel repair ${pkgname}-${pkgver}-${TAG}.whl -w /tmp

  # use libs from OT wheel
  cd /tmp
  unzip ${pkgname}-${pkgver}-${TAG}.whl
  patchelf --remove-rpath ${pkgname}/_${pkgname}.so
  patchelf --force-rpath --set-rpath "\$ORIGIN/../${pkgname}.libs:\$ORIGIN/../openturns.libs" ${pkgname}/_${pkgname}.so
  for wfile in `ls ${pkgname}.libs`; do grep -Eq "lib${pkgname}|libfftw3" <<< "${wfile}" || rm ${pkgname}.libs/${wfile}; done
  zip -r /io/wheelhouse/${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}.libs ${pkgname}-${pkgver}.dist-info
  cd -

  # test
  pip install ${pkgname} --no-index -f /io/wheelhouse
  python -c "import ${pkgname}; print(${pkgname}.__version__)"
done


# upload
pip install "cryptography<3.4" twine
twine --version
if test -n "${TRAVIS_TAG}"
then
  twine upload /io/wheelhouse/openturns-${VERSION}-${TAG}.whl || echo "done"
fi
