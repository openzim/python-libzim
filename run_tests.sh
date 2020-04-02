#!/bin/bash
rm -rf tests/kiwix-test-*

python3 tests/test_pyzim.py
rm -rf tests/kiwix-test-*