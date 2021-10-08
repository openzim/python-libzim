# python-libzim

`libzim` module allows you to read and write [ZIM
files](https://openzim.org) in Python. It provides a shallow python
interface on top of the [C++ `libzim` library](https://github.com/openzim/libzim).

It is primarily used in [openZIM](https://github.com/openzim/) scrapers like [`sotoki`](https://github.com/openzim/sotoki) or [`youtube2zim`](https://github.com/openzim/youtube).

[![Build Status](https://github.com/openzim/python-libzim/workflows/test/badge.svg?query=branch%3Amaster)](https://github.com/openzim/python-libzim/actions?query=branch%3Amaster)
[![CodeFactor](https://www.codefactor.io/repository/github/openzim/python-libzim/badge)](https://www.codefactor.io/repository/github/openzim/python-libzim)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PyPI version shields.io](https://img.shields.io/pypi/v/libzim.svg)](https://pypi.org/project/libzim/)
[![codecov](https://codecov.io/gh/openzim/python-libzim/branch/master/graph/badge.svg)](https://codecov.io/gh/openzim/python-libzim)

## Installation

```sh
pip install libzim
```

The [PyPI package](https://pypi.org/project/libzim/) is available for x86_64 macOS and GNU/Linux only. It bundles a [recent release](http://download.openzim.org/release/libzim/) of the C++ libzim.

On other platforms, you'd have to [compile C++ libzim from
source](https://github.com/openzim/libzim) first then build this one, adjusting `LD_LIBRARY_PATH`.

## Contributions

``` sh
git clone git@github.com:openzim/python-libzim.git && cd python-libzim
# python -m venv env && source env/bin/activate
pip install -U setuptools invoke
invoke download-libzim install-dev build-ext test
# invoke --list for available development helpers
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for additional details then [Open a ticket](https://github.com/openzim/python-libzim/issues/new) or submit a Pull Request on Github 🤗!

## Usage

### Read a ZIM file

```python
from libzim.reader import Archive
from libzim.search import Query, Searcher
from libzim.suggestion import SuggestionSearcher

zim = Archive("test.zim")
print(f"Main entry is at {zim.main_entry.get_item().path}")
entry = zim.get_entry_by_path("home/fr")
print(f"Entry {entry.title} at {entry.path} is {entry.get_item().size}b.")
print(bytes(entry.get_item().content).decode("UTF-8"))

# searching using full-text index
search_string = "Welcome"
query = Query().set_query(search_string)
searcher = Searcher(zim)
search = searcher.search(query)
search_count = search.getEstimatedMatches()
print(f"there are {search_count} matches for {search_string}")
print(list(search.getResults(0, search_count)))

# accessing suggestions
search_string = "kiwix"
suggestion_searcher = SuggestionSearcher(zim)
suggestion = suggestion_searcher.suggest(search_string)
suggestion_count = suggestion.getEstimatedMatches()
print(f"there are {suggestion_count} matches for {search_string}")
print(list(suggestion.getResults(0, suggestion_count)))
```

### Write a ZIM file

```py
from libzim.writer import Creator, Item, StringProvider, FileProvider, Hint


class MyItem(Item):
    def __init__(self, title, path, content = "", fpath = None):
        super().__init__()
        self.path = path
        self.title = title
        self.content = content
        self.fpath = fpath

    def get_path(self):
        return self.path

    def get_title(self):
        return self.title

    def get_mimetype(self):
        return "text/html"

    def get_contentprovider(self):
        if self.fpath is not None:
            return FileProvider(self.fpath)
        return StringProvider(self.content)
       
    def get_hints(self):
        return {Hint.FRONT_ARTICLE: True}


content = """<html><head><meta charset="UTF-8"><title>Web Page Title</title></head>
<body><h1>Welcome to this ZIM</h1><p>Kiwix</p></body></html>"""

item = MyItem("Hello Kiwix", "home", content)
item2 = MyItem("Bonjour Kiwix", "home/fr", None, "home-fr.html")

with Creator("test.zim").config_indexing(True, "eng") as creator:
    creator.set_mainpath("home")
    creator.add_item(item)
    creator.add_item(item2)
    for name, value in {
        "creator": "python-libzim",
        "description": "Created in python",
        "name": "my-zim",
        "publisher": "You",
        "title": "Test ZIM",
    }.items():

        creator.add_metadata(name.title(), value)
```


## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0) or later, see
[LICENSE](LICENSE) for more details.
