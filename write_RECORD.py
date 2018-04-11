#!/usr/bin/env python

import os
import hashlib
import base64

import sys
if len(sys.argv) != 2:
    raise ValueError('no version')
version = sys.argv[1]

path = os.path.join('openturns-' + version + '.dist-info', 'RECORD')

with open(path, 'w') as record:
    for f in os.listdir('openturns'):
        fpath = os.path.join('openturns', f)
        size = os.path.getsize(fpath)
        if os.path.isfile(fpath):
            data = open(fpath, 'rb').read()
            digest = hashlib.sha256(data).digest()
            checksum = base64.urlsafe_b64encode(digest).decode()
            size = len(data)
            record.write(fpath + ',sha256=' + checksum + ',' + str(size) + '\n')
