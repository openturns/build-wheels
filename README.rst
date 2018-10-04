.. image:: https://travis-ci.org/openturns/build-wheels.svg?branch=master
    :target: https://travis-ci.org/openturns/build-wheels

.. image:: https://ci.appveyor.com/api/projects/status/a4qwm56rwe40e0m5?svg=true
    :target: https://ci.appveyor.com/project/openturns/build-wheels

================
OpenTURNS wheels
================

Script to build Python wheel packages for installation with pip::

    pip install openturns --user

Relevant links:

- https://www.python.org/dev/peps/pep-0427/
- https://www.python.org/dev/peps/pep-0513/
- https://github.com/pypa/manylinux
- https://hynek.me/articles/sharing-your-labor-of-love-pypi-quick-and-dirty/
- https://pypi.python.org/pypi/openturns
- https://github.com/matthew-brett/multibuild

Todo:

- OSX target
- hmat dependency

Note:

The version string must be updated in .travis.yml, appveyor.yml and METADATA files.
