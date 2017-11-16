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


curl -L https://github.com/01org/tbb/archive/2018_U1.tar.gz -o /tmp/2018_U1.tar.gz
tar xzf /tmp/2018_U1.tar.gz
cd tbb-2018_U1
make -j2
cp `find . -name "libtbb*.so*" | grep release` /usr/local/lib
cd /usr/local/lib
ln -sf libtbb.so.2 libtbb.so
ln -sf libtbbmalloc.so.2 libtbbmalloc.so
ln -sf libtbbmalloc_proxy.so.2 libtbbmalloc_proxy.so
cd -
cp -r ./include/tbb /usr/local/include
cd ..
