#!/bin/sh

# Apple pre-compiled XcFrameworks, defined in xcfs/Package.swift, with checksum control:
swift run --package-path xcfs

# Python frameworks and files: 
curl -OL https://github.com/holzschu/a-shell/releases/download/cpython_05_22/pythonInstall.tar.gz
tar xzf pythonInstall.tar.gz

