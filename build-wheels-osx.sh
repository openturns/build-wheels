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
delocate-wheel -w ${TRAVIS_BUILD_DIR}/wheelhouse -v openturns-${VERSION}-${TAG}.whl
delocate-listdeps --all ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl

# move conf file next to lib so it can be found using dladdr when relocated
mkdir -p openturns/.dylibs
cp -v ../../../etc/openturns/openturns.conf openturns/.dylibs
zip -u ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/openturns.conf

# add missing libs
ls -l ${HOME}/miniforge/lib/
for libname in libicuuc.68 libicudata.68 libiconv.2 libcurl.4 libnghttp2.14 libssh2.1 libgssapi_krb5.2.2 libkrb5.3.3 libk5crypto.3.1 libcom_err.3.0 libkrb5support.1.1 libamd.2 libcamd.2 libcolamd.2 libcholmod.3 libccolamd.2 libsuitesparseconfig.5 libblas.3 liblapack.3 libgfortran.5 libquadmath.0 libCgl.1 libOsiClp.1 libOsi.1 libClp.1 libCoinUtils.3 libmumps_common_seq-5.2.1 libpord_seq-5.2.1 libesmumps-6 libscotch-6 libscotcherr-6 libgflags.2.2
do
  cp ${HOME}/miniforge/lib/${libname}.dylib openturns/.dylibs
  zip -u ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl openturns/.dylibs/${libname}.dylib
done

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
cd ${TRAVIS_BUILD_DIR}
rm -r ${HOME}/miniforge
bash /tmp/Miniforge3-MacOSX-x86_64.sh -b -p ${HOME}/miniforge
conda install -y python=${PYVERD} pip twine
pip install openturns --no-index -f ${TRAVIS_BUILD_DIR}/wheelhouse
python -c "import openturns as ot; print(ot.Normal(3).getRealization())"

# upload
twine --version
if test -n "${TRAVIS_TAG}"
then
  twine upload --verbose ${TRAVIS_BUILD_DIR}/wheelhouse/openturns-${VERSION}-${TAG}.whl || echo "done"
#   twine upload --verbose ${TRAVIS_BUILD_DIR}/wheelhouse/ot*.whl || echo "done"
fi
