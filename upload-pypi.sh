#!/bin/sh

VERSION=1.10

set -e -x
for ABI in cp27mu cp35m cp36m
do
  PYVER=`echo ${ABI}| cut -c3-4`
  wget -c https://github.com/openturns/build-wheel/releases/download/v${VERSION}/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux1_x86_64.whl -P /tmp
  twine upload -r test /tmp/openturns-${VERSION}-cp${PYVER}-${ABI}-manylinux1_x86_64.whl
done
