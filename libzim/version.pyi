from __future__ import annotations

import sys
from collections import OrderedDict
from typing import TextIO

def print_versions(out: TextIO = sys.stdout) -> None: ...
def get_versions() -> OrderedDict[str, str]: ...
def get_libzim_version() -> str: ...
