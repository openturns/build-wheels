#!/bin/sh

set -e -x

ln -s /usr/bin/cmake28 /usr/bin/cmake
ln -s /usr/bin/ctest28 /usr/bin/ctest

yum install -y blas-devel lapack-devel libxml2-devel pcre-devel zip

curl -L https://github.com/beltoforion/muparser/archive/v2.2.5.tar.gz -o /tmp/v2.2.5.tar.gz
tar xzf /tmp/v2.2.5.tar.gz
cd muparser-2.2.5
./configure --disable-samples
make -j2
make install
cd ..


curl -L https://github.com/stevengj/nlopt/releases/download/nlopt-2.4.2/nlopt-2.4.2.tar.gz -o /tmp/nlopt-2.4.2.tar.gz
tar xzf /tmp/nlopt-2.4.2.tar.gz
cd nlopt-2.4.2
./configure --without-python --without-guile --without-octave --enable-shared --disable-static
make -j2
make install
cd ..


curl -L https://github.com/swig/swig/archive/rel-3.0.12.tar.gz -o /tmp/rel-3.0.12.tar.gz
tar xzf /tmp/rel-3.0.12.tar.gz
cd swig-rel-3.0.12
./autogen.sh
./configure
make -j2
make install
cd ..
