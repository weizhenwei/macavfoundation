#!/bin/sh

# ATTENTION: This script should be run at the root dir of openDMD project.

find ./MacAVCaptureVideo -name *.h -o -name *.cpp -o -name *.m -o -name *.mm | xargs ./tools/cpplint.py

