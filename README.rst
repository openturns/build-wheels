.. image:: https://travis-ci.com/openturns/build-wheels.svg?branch=master
    :target: https://travis-ci.com/openturns/build-wheels

.. image:: https://ci.appveyor.com/api/projects/status/uut71pqklp8eksl1?svg=true
    :target: https://ci.appveyor.com/project/openturns/build-wheels

.. image:: https://github.com/openturns/build-wheels/actions/workflows/nightly.yml/badge.svg?branch=master
    :target: https://github.com/openturns/build-wheels/actions/workflows/nightly.yml

================
OpenTURNS wheels
================

Script to build Python wheel packages for installation with pip::

    pip3 install openturns --user

Also provides nightly builds::

    pip3 install --pre --extra-index-url https://pypi.anaconda.org/openturns-wheels-nightly/simple --upgrade --force-reinstall openturns

Relevant links:

- https://www.python.org/dev/peps/pep-0427/
- https://www.python.org/dev/peps/pep-0513/
- https://www.python.org/dev/peps/pep-0571/
- https://www.python.org/dev/peps/pep-0599/
- https://www.python.org/dev/peps/pep-0600/
- https://github.com/pypa/manylinux
- https://hynek.me/articles/sharing-your-labor-of-love-pypi-quick-and-dirty/
- https://github.com/matthew-brett/multibuild
- https://pypi.python.org/pypi/openturns
- https://anaconda.org/openturns-wheels-nightly/openturns

Note:

The version string must be updated in .travis.yml and appveyor.yml
