from __future__ import annotations

from collections.abc import Iterator

from typing_extensions import disjoint_base

from libzim.reader import Archive

__all__ = ["SuggestionResultSet", "SuggestionSearch", "SuggestionSearcher"]

@disjoint_base
class SuggestionResultSet:
    def __iter__(self) -> Iterator[str]: ...

@disjoint_base
class SuggestionSearch:
    def get_estimated_matches(self) -> int: ...
    def get_results(self, start: int, count: int) -> SuggestionResultSet: ...

@disjoint_base
class SuggestionSearcher:
    def __init__(self, archive: Archive) -> None: ...
    def suggest(self, query: str) -> SuggestionSearch: ...
