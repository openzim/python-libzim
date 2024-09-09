from __future__ import annotations

from collections.abc import Iterator

from libzim.reader import Archive

class SuggestionResultSet:
    def __iter__(self) -> Iterator[str]: ...

class SuggestionSearch:
    def getEstimatedMatches(self) -> int: ...  # noqa: N802
    def getResults(  # noqa: N802
        self, start: int, count: int
    ) -> SuggestionResultSet: ...

class SuggestionSearcher:
    def __init__(self, archive: Archive) -> None: ...
    def suggest(self, query: str) -> SuggestionSearch: ...
