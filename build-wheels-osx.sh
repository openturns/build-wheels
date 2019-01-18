#!/bin/sh

set -e -x

VERSION="$1"
PYVER="$2"
ABI="$3"
PLATFORM="$4"

TAG="cp${PYVER}-${ABI}-${PLATFORM}"
PYVERD=${PYVER:0:1}.${PYVER:1:1}
# if test "${PYVER:0:1}" = "3"
# then
#   PYVERD=${PYVERD}m
# fi

# SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
SCRIPTPATH=${TRAVIS_BUILD_DIR}

wget --no-check-certificate https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -P /tmp
bash /tmp/Miniconda3-latest-MacOSX-x86_64.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
conda config --add channels conda-forge
conda install -y python=${PYVERD} openturns delocate

cd ${HOME}/miniconda/lib/python${PYVERD}/site-packages/

# write metadata
mkdir openturns-${VERSION}.dist-info
cp ${SCRIPTPATH}/METADATA openturns-${VERSION}.dist-info
python ${SCRIPTPATH}/write_WHEEL.py ${VERSION} ${TAG}
python ${SCRIPTPATH}/write_RECORD.py ${VERSION}

# create archive
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${TRAVIS_BUILD_DIR}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl

conda remove -y openturns
rm -r openturns-${VERSION}.dist-info
pip install openturns --no-index -f ${TRAVIS_BUILD_DIR}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"
