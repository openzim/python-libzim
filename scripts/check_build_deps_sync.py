#!/usr/bin/env python3
"""Check that build-system.requires and the `build` extra stay in sync.

PEP 518 requires build-system.requires to be static TOML, parsed before any
project or build-backend code runs, so it cannot reference
project.optional-dependencies.build (or vice-versa): the two lists must be
duplicated by hand. This script is the drift check for that duplication.
"""

import sys
import tomllib
from pathlib import Path


def main() -> int:
    pyproject = tomllib.loads(Path("pyproject.toml").read_text())
    build_system_requires = pyproject["build-system"]["requires"]
    build_extra = pyproject["project"]["optional-dependencies"]["build"]

    if build_system_requires == build_extra:
        print("build-system.requires and the `build` extra are in sync")  # noqa: T201
        return 0

    print(  # noqa: T201
        "error: build-system.requires and the `build` extra have drifted apart"
    )
    print(f"  build-system.requires       = {build_system_requires}")  # noqa: T201
    print(f"  optional-dependencies.build = {build_extra}")  # noqa: T201
    return 1


if __name__ == "__main__":
    sys.exit(main())
