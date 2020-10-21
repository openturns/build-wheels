#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"
PLATFORM="$4"

TAG="cp${PYVER}-${ABI}-${PLATFORM}"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
SCRIPTPATH=${TRAVIS_BUILD_DIR}

# setup a new conda env to retrieve openturns and its dependencies
wget --no-check-certificate https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -P /tmp
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p ${HOME}/miniconda
export PATH="${HOME}/miniconda/bin:${PATH}"
conda config --add channels conda-forge
conda install -y python=${PYVERD} openturns=${VERSION} delocate

# create wheel archive
cd ${HOME}/miniconda/lib/python${PYVERD}/site-packages/
python ${SCRIPTPATH}/write_RECORD.py ${VERSION}
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

# gather dependencies
delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${TRAVIS_BUILD_DIR}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# move conf file next to lib so it can be found using dladr when relocated
mkdir openturns/.dylibs
cp ../../../etc/openturns/openturns.conf openturns/.dylibs
zip -u ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/openturns.conf

# test in a fresh conda env
cd ${TRAVIS_BUILD_DIR}
rm -r ${HOME}/miniconda
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p ${HOME}/miniconda
conda install -y python=${PYVERD} pip twine
pip install openturns --no-index -f ${TRAVIS_BUILD_DIR}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"

# upload
twine --version
if test -n "${TRAVIS_TAG}"
then
  twine upload ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl || echo "done"
fi
