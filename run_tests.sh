#!/bin/bash
rm -rf tests/kiwix-test-*

pytest -v
rm -rf tests/kiwix-test-*