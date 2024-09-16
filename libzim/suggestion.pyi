from __future__ import annotations

from collections.abc import Iterator

from libzim.reader import Archive

class SuggestionResultSet:
    def __iter__(self) -> Iterator[str]: ...

class SuggestionSearch:
    def get_estimated_matches(self) -> int: ...  # noqa: N802
    def get_results(  # noqa: N802
        self, start: int, count: int
    ) -> SuggestionResultSet: ...

class SuggestionSearcher:
    def __init__(self, archive: Archive) -> None: ...
    def suggest(self, query: str) -> SuggestionSearch: ...
