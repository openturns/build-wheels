#!/bin/bash

if test "$#" -lt 1
then
  echo -e "1. linux\n2. aarch64\n3. mingw\n\n> "
  read choice
else
  choice="$1"
fi

case $choice in
  "1" | "linux")
    docker pull openturns/manylinux2014_x86_64
    docker run --rm -e MAKEFLAGS -v `pwd`:/io openturns/manylinux2014_x86_64 /io/build-wheels-linux.sh openturns master
    ;;
  "2" | "aarch64")
    docker pull openturns/manylinux2014_aarch64
    docker run --rm -e MAKEFLAGS -v `pwd`:/io openturns/manylinux2014_aarch64 /io/build-wheels-linux.sh openturns master
    ;;
  "3" | "mingw")
    docker pull openturns/archlinux-mingw
    docker run --rm -e MAKEFLAGS -v `pwd`:/io openturns/archlinux-mingw /io/build-wheels-mingw.sh openturns master
    ;;
  *)
    echo "sorry?"
    exit 1
    ;;
esac
