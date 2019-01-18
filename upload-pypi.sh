#!/bin/sh

# upload wheels to PyPI repository using Twine
# sudo apt install twine
# it uses settings from the .pypirc file:

# [test]
# #repository = https://test.pypi.org/legacy/
# repository: https://upload.pypi.org/legacy/
# username = doe
# password = moo


VERSION=1.12

set -e -x
for ABI in cp27mu cp34m cp35m cp36m cp37m
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux1_x86_64.whl -P /tmp
  twine upload -r test /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux1_x86_64.whl
done

for ABI in cp27m cp36m cp37m
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-win_amd64.whl -P /tmp
  twine upload -r test /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-win_amd64.whl
done

for ABI in cp27m cp36m cp37m
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-macosx_10_10_x86_64.whl -P /tmp
  twine upload -r test /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-macosx_10_10_x86_64.whl
done
