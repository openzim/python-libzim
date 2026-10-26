from __future__ import annotations

from collections.abc import Iterator
from typing import Self

from typing_extensions import disjoint_base

from libzim.reader import Archive

__all__ = ["Query", "Search", "SearchResult", "SearchResultSet", "Searcher"]

@disjoint_base
class Query:
    def set_query(self, query: str) -> Self: ...

@disjoint_base
class SearchResult:
    archive: Archive
    path: str
    title: str
    snippet: str
    def __init__(
        self, archive: Archive, path: str, title: str, snippet: str
    ) -> None: ...

@disjoint_base
class SearchResultSet:
    def __iter__(self) -> Iterator[SearchResult]: ...

@disjoint_base
class Search:
    def get_estimated_matches(self) -> int: ...
    def get_results(self, start: int, count: int) -> SearchResultSet: ...

@disjoint_base
class Searcher:
    def __init__(
        self,
        archive: Archive | list[Archive] | tuple[Archive, ...] | None = None,
        *extra_archives: Archive,
    ) -> None: ...
    def add_archive(self, archive: Archive) -> None: ...
    def search(self, query: Query) -> Search: ...
