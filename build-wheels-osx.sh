#!/bin/sh

set -e -x

VERSION="$1"
ABI="$2"
PLATFORM="$3"

PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVERD=${PYTAG:2:1}.${PYTAG:3}
SCRIPTPATH=${PWD}

# setup a new conda env to retrieve openturns and its dependencies
wget --no-check-certificate https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh -P /tmp
bash /tmp/Miniforge3-MacOSX-x86_64.sh -b -p ${HOME}/miniforge
export PATH="${HOME}/miniforge/bin:${PATH}"
conda install -y python=${PYVERD} openturns=${VERSION} delocate

# create archive
cd ${HOME}/miniforge/lib/python${PYVERD}/site-packages/
python ${SCRIPTPATH}/write_RECORD.py openturns ${VERSION}
zip -r openturns-${VERSION}-${TAG}.whl openturns openturns-${VERSION}.dist-info

# gather dependencies
delocate-listdeps openturns-${VERSION}-${TAG}.whl
delocate-wheel -w ${SCRIPTPATH}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns/.dylibs
cp -v ../../../etc/openturns/openturns.conf openturns/.dylibs
zip -u ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/openturns.conf

# add missing libs
ls -l ${HOME}/miniforge/lib/
for libname in libblas.3 libcblas.3 liblapack.3
do
  cp ${HOME}/miniforge/lib/${libname}.dylib openturns/.dylibs
  zip -u ${SCRIPTPATH}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/${libname}.dylib
done

# modules
# for pkgnamever in otfftw-0.11 otmixmod-0.12 otmorris-0.10 otpmml-1.11 otrobopt-0.9 otsubsetinverse-1.8 otsvm-0.10
# do
#   pkgname=`echo ${pkgnamever} | cut -d "-" -f1`
#   pkgver=`echo ${pkgnamever} | cut -d "-" -f2`
#   conda install -y ${pkgname}=${pkgver}
# 
#   # create archive
#   python ${SCRIPTPATH}/write_RECORD.py ${pkgname} ${pkgver}
#   zip -r ${pkgname}-${pkgver}-${TAG}.whl ${pkgname} ${pkgname}-${pkgver}.dist-info
# 
#   delocate-listdeps ${pkgname}-${pkgver}-${TAG}.whl
#   delocate-wheel -w /tmp -v ${pkgname}-${pkgver}-${TAG}.whl
# 
#   # use libs from OT wheel
#   cd /tmp
#   unzip ${pkgname}-${pkgver}-${TAG}.whl
#   install_name_tool -add_rpath @loader_path/../openturns.libs ${pkgname}/_${pkgname}.so
#   otool -l ${pkgname}/_${pkgname}.so
#   cd -
# 
# done

# test in a fresh conda env
cd ${SCRIPTPATH}
rm -r ${HOME}/miniforge
bash /tmp/Miniforge3-MacOSX-x86_64.sh -b -p ${HOME}/miniforge
conda install -y python=${PYVERD} pip twine
pip install openturns --no-index -f ${SCRIPTPATH}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"

