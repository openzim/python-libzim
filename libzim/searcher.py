""" libzim reader module

    - Archive to open and read ZIM files
    - `Archive` gives access to all `Entry`
    - `Entry` gives access to `Item` (content)

    Usage:

    with Archive(fpath) as zim:
        entry = zim.get_entry_by_path(zim.main_entry.path)
        print(f"Article {entry.title} at {entry.path} is "
              f"{entry.get_item().content.nbytes}b")
    """

# flake8: noqa
from .wrapper import Searcher, PyQuery as Query


__all__ = ["Searcher", "Query"]
