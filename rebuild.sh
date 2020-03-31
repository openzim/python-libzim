#!/bin/bash
rm pyzim/pyzim.cpp
rm -rf build/
rm pyzim.so

python setup.py build_ext -i
