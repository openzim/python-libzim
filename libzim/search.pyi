from __future__ import annotations

from collections.abc import Iterator
from typing import Self

from libzim.reader import Archive


class Query:

    def set_query(self, query: str) -> Self: ...


class SearchResult:

    archive: Archive
    path: str


class SearchResultSet:

    def __iter__(self) -> Iterator[SearchResult]: ...


class Search:

    def getEstimatedMatches(self) -> int: ...  # noqa: N802

    def getResults(self, start: int, count: int) -> SearchResultSet: ...  # noqa: N802


class Searcher:

    def __init__(self) -> None: ...

    def addArchive(self, archive: Archive) -> None: ...

    def search(self, query: Query) -> Search: ...