#!/bin/bash
rm pyzim/pyzim.cpp
rm -rf build/
rm *.so

python3 setup.py build_ext -i
