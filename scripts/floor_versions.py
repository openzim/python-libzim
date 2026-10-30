#!/usr/bin/env python3
"""Print `name==version` pins for the floor of build-system.requires in pyproject.toml.

Used by CI to install and test against the lowest versions we claim to
support, without hardcoding those versions a second time in the workflow.
"""

import tomllib
from pathlib import Path

from packaging.requirements import Requirement

pyproject = tomllib.loads(Path("pyproject.toml").read_text())

pins = []
for req in pyproject["build-system"]["requires"]:
    requirement = Requirement(req)
    if requirement.marker and not requirement.marker.evaluate():
        continue
    # exact pins (e.g. delocate) have nothing to float, skip them
    floor = next(
        (spec.version for spec in requirement.specifier if spec.operator == ">="),
        None,
    )
    if floor is not None:
        pins.append(f"{requirement.name}=={floor}")

print(" ".join(pins))  # noqa: T201
