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
    for subdir in ['openturns', 'openturns-' + version + '.dist-info']:
        for f in os.listdir(subdir):
            fpath = os.path.join(subdir, f)
            size = os.path.getsize(fpath)
            if os.path.isfile(fpath):
                data = open(fpath, 'rb').read()
                digest = hashlib.sha256(data).digest()
                checksum = base64.urlsafe_b64encode(digest).decode()
                size = len(data)
                if not 'RECORD' in fpath:
                    record.write(fpath + ',sha256=' + checksum + ',' + str(size) + '\n')
                else:
                    record.write(fpath + ',,\n')
