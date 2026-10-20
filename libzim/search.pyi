from __future__ import annotations

from collections.abc import Iterator
from typing import Self

from libzim.reader import Archive

class Query:
    def set_query(self, query: str) -> Self: ...

class SearchResult:
    archive: Archive
    path: str
    title: str
    snippet: str

class SearchResultSet:
    def __iter__(self) -> Iterator[SearchResult]: ...

class Search:
    def get_estimated_matches(self) -> int: ...
    def get_results(self, start: int, count: int) -> SearchResultSet: ...

class Searcher:
    def __init__(
        self, archive: Archive | list[Archive] | None = None, *extra_archives: Archive
    ) -> None: ...
    def add_archive(self, archive: Archive) -> None: ...
    def search(self, query: Query) -> Search: ...
