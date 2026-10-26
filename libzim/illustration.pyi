from __future__ import annotations

from collections.abc import Mapping
from typing import NamedTuple, Self

__all__ = ["IllustrationInfo"]

class _IllustrationInfoTuple(NamedTuple):
    width: int
    height: int
    scale: float
    extra_attributes: Mapping[str, str]

class IllustrationInfo(_IllustrationInfoTuple):
    """Information about an illustration in a ZIM archive."""

    def __new__(
        cls,
        width: int = 0,
        height: int = 0,
        scale: float = 1.0,
        extra_attributes: Mapping[str, str] | None = None,
    ) -> Self: ...
    @staticmethod
    def from_metadata_item_name(name: str) -> IllustrationInfo: ...
    def as_metadata_item_name(self) -> str: ...
