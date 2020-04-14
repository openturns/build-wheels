#!/bin/sh

# upload wheels to PyPI repository using Twine
# sudo apt install twine
# it uses settings from the .pypirc file:

#[distutils]
#index-servers =
#  pypi
# [pypi]
# #repository = https://test.pypi.org/legacy/
# repository: https://upload.pypi.org/legacy/
# username: doe
# password: moo


VERSION=1.15rc1

set -e
for ABI in cp36m cp37m cp38
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux2010_x86_64.whl -P /tmp
  twine upload /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux2010_x86_64.whl
done

for ABI in cp36m cp37m cp38
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-win_amd64.whl -P /tmp
  twine upload /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-win_amd64.whl
done

for ABI in cp36m cp37m cp38
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-macosx_10_9_x86_64.whl -P /tmp
  twine upload /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-macosx_10_9_x86_64.whl
done
