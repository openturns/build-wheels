#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"
PLATFORM="$4"

TAG="cp${PYVER}-${ABI}-${PLATFORM}"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
SCRIPTPATH=${TRAVIS_BUILD_DIR}

wget --no-check-certificate https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -P /tmp
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p ${HOME}/miniconda
export PATH="${HOME}/miniconda/bin:${PATH}"
conda config --add channels conda-forge
conda install -y python=${PYVERD} openturns=${VERSION} delocate

cd ${HOME}/miniconda/lib/python${PYVERD}/site-packages/

# write metadata
python ${SCRIPTPATH}/write_RECORD.py ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${TRAVIS_BUILD_DIR}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# move conf file next to lib so it can be found using dladr when relocated
mkdir openturns/.dylibs
cp ../../../etc/openturns/openturns.conf openturns/.dylibs
zip -u ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/openturns.conf

# missing libs
for libname in libquadmath.0 libgcc_s.1 libc++abi.1 libgfortran.4 liblapack.3
do
  cp ${HOME}/miniconda/lib/${libname}.dylib openturns/.dylibs
  zip -u ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/${libname}.dylib
done

cd ${TRAVIS_BUILD_DIR}
rm -r ${HOME}/miniconda
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p ${HOME}/miniconda
conda install -y python=${PYVERD} pip twine

# test
pip install openturns --no-index -f ${TRAVIS_BUILD_DIR}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"

# upload
twine --version
if test -n "${TRAVIS_TAG}"
then
  twine upload ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl
fi
