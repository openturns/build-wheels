#!/usr/bin/env python

import os
import sys
if len(sys.argv) != 3:
    raise ValueError('no version, tag')
version = sys.argv[1]
tag = sys.argv[2]

path = os.path.join('openturns-' + version + '.dist-info', 'WHEEL')

with open(path, 'w') as wheel:
    wheel.write('Wheel-Version: 1.0\n')
    wheel.write('Generator: custom\n')
    wheel.write('Root-Is-Purelib: false\n')
    wheel.write('Tag: ' + tag + '\n')

