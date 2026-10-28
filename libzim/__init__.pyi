from libzim import (
    illustration,  # pyright: ignore[reportUnusedImport]
    reader,  # pyright: ignore[reportUnusedImport]
    search,  # pyright: ignore[reportUnusedImport]
    suggestion,  # pyright: ignore[reportUnusedImport]
    version,  # pyright: ignore[reportUnusedImport]
)

__all__ = ["illustration", "reader", "search", "suggestion", "version"]

try:
    from libzim import writer as writer

    __all__.append("writer")
except ImportError:
    pass
