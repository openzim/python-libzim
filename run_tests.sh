#!/bin/bash
rm -rf tests/kiwix-test-*

python3 tests/test_libzim.py
rm -rf tests/kiwix-test-*