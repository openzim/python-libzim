from __future__ import annotations

from collections.abc import Mapping
from typing import NamedTuple

class IllustrationInfo(NamedTuple):
    """Information about an illustration in a ZIM archive."""

    width: int = 0
    height: int = 0
    scale: float = 1.0
    extra_attributes: Mapping[str, str] = {}
    @staticmethod
    def from_metadata_item_name(name: str) -> IllustrationInfo: ...
    def as_metadata_item_name(self) -> str: ...
