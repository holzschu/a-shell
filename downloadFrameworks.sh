#!/bin/sh
set -eu

# Apple pre-compiled XcFrameworks, defined in xcfs/Package.swift, with checksum control:
swift package --package-path xcfs "$@" resolve

# Python frameworks and files: 
curl -fOL https://github.com/holzschu/a-shell/releases/download/cpython_05_22/pythonInstall.tar.gz
tar xzf pythonInstall.tar.gz

