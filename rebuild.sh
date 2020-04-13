#!/bin/bash
rm libzim/libzim.cpp
rm -rf build/
rm libzim.so

python3 setup.py build_ext -i
