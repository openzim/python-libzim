# python-libzim

`libzim` module allows you to read and write [ZIM
files](https://openzim.org) in Python. It provides a shallow python
interface on top of the [C++ `libzim` library](https://github.com/openzim/libzim).

It is primarily used in [openZIM](https://github.com/openzim/) scrapers like [`sotoki`](https://github.com/openzim/sotoki) or [`youtube2zim`](https://github.com/openzim/youtube).

[![Build Status](https://github.com/openzim/python-libzim/workflows/test/badge.svg?query=branch%3Amain)](https://github.com/openzim/python-libzim/actions?query=branch%3Amain)
[![CodeFactor](https://www.codefactor.io/repository/github/openzim/python-libzim/badge)](https://www.codefactor.io/repository/github/openzim/python-libzim)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PyPI version shields.io](https://img.shields.io/pypi/v/libzim.svg)](https://pypi.org/project/libzim/)
[![PyPI - Python Version](https://img.shields.io/pypi/pyversions/libzim.svg)](https://pypi.org/project/libzim)
[![codecov](https://codecov.io/gh/openzim/python-libzim/branch/main/graph/badge.svg)](https://codecov.io/gh/openzim/python-libzim)
[![Read the Docs](https://img.shields.io/readthedocs/python-libzim)](https://python-libzim.readthedocs.io/)

## Installation

```sh
pip install libzim
```

Our [PyPI wheels](https://pypi.org/project/libzim/) bundle a [recent release](https://download.openzim.org/release/libzim/) of the C++ libzim and are available for the following platforms:

- macOS for `x86_64` and `arm64`
- GNU/Linux for `x86_64`, `armhf` and `aarch64`
- Linux+musl for `x86_64` and `aarch64`
- Windows for `x64`

Wheels are available for CPython only (but can be built for Pypy).

Free-threaded CPython is not supported. If you use a free-threaded CPython, GIL must be turned on (using the environment variable PYTHON_GIL or the command-line option -X gil). If you don't turn it on yourself, GIL will be forced-on and you will get a warning. Only few methods support the GIL to be disabled.

Users on other platforms can install the source distribution (see [Building](#Building) below). 


## Contributions

```sh
git clone git@github.com:openzim/python-libzim.git && cd python-libzim
# hatch run test:coverage
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
import base64
import pathlib

from libzim.writer import Creator, Item, StringProvider, FileProvider, Hint


class MyItem(Item):
    def __init__(self, title, path, content="", fpath=None):
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

pathlib.Path("home-fr.html").write_text(
    """<html><head><meta charset="UTF-8">
    <title>Bonjour</title></head>
    <body><h1>this is home-fr</h1></body></html>"""
)

item = MyItem("Hello Kiwix", "home", content)
item2 = MyItem("Bonjour Kiwix", "home/fr", None, "home-fr.html")

# illustration = pathlib.Path("icon48x48.png").read_bytes()
illustration = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwAQMAAABtzGvEAAAAGXRFWHRTb2Z0d2FyZQBB"
    "ZG9iZSBJbWFnZVJlYWR5ccllPAAAAANQTFRFR3BMgvrS0gAAAAF0Uk5TAEDm2GYAAAAN"
    "SURBVBjTY2AYBdQEAAFQAAGn4toWAAAAAElFTkSuQmCC"
)

with Creator("test.zim").config_indexing(True, "eng") as creator:
    creator.set_mainpath("home")
    creator.add_item(item)
    creator.add_item(item2)
    creator.add_illustration(48, illustration)
    for name, value in {
        "creator": "python-libzim",
        "description": "Created in python",
        "name": "my-zim",
        "publisher": "You",
        "title": "Test ZIM",
        "language": "eng",
        "date": "2024-06-30",
    }.items():

        creator.add_metadata(name.title(), value)
```

#### Thread safety

> The reading part of the libzim is most of the time thread safe. Searching and creating part are not. [libzim documentation](https://libzim.readthedocs.io/en/latest/usage.html#introduction)

`python-libzim` disables the [GIL](https://wiki.python.org/moin/GlobalInterpreterLock) on most of C++ libzim calls. You **must prevent concurrent access** yourself. This is easily done by wrapping all creator calls with a [`threading.Lock()`](https://docs.python.org/3/library/threading.html#lock-objects)

```py
lock = threading.Lock()
with Creator("test.zim") as creator:

    # Thread #1
    with lock:
        creator.add_item(item1)

    # Thread #2
    with lock:
        creator.add_item(item2)
```

#### Type hints

`libzim` being a binary extension, there is no Python source to provide types information. We provide them as type stub files. When using `pyright`, you would normally receive a warning when importing from `libzim` as there could be discrepencies between actual sources and the (manually crafted) stub files.

You can disable the warning via `reportMissingModuleSource = "none"`.

## Building

`libzim` package building offers different behaviors via environment variables

| Variable                         | Example                                  | Use case |
| -------------------------------- | ---------------------------------------- | -------- |
| `LIBZIM_DL_VERSION`              | `8.1.1` or `2023-04-14`                     | Specify the C++ libzim binary version to download and bundle. Either a release version string or a date, in which case it downloads a nightly |
| `USE_SYSTEM_LIBZIM`              | `1`                                      | Uses `LDFLAG` and `CFLAGS` to find the libzim to link against. Resulting wheel won't bundle C++ libzim. |
| `DONT_DOWNLOAD_LIBZIM`           | `1`                                      | Disable downloading of C++ libzim. Place headers in `include/` and libzim dylib/so in `libzim/` if no using system libzim. It will be bundled in wheel. |
| `PROFILE`                        | `0`                                      | Enable profile tracing in Cython extension. Required for Cython code coverage reporting. |
| `SIGN_APPLE`                     | `1`                                      | Set to sign and notarize the extension for macOS. Requires following informations |
| `APPLE_SIGNING_IDENTITY`         | `Developer ID Application: OrgName (ID)` | Required for signing on macOS |
| `APPLE_SIGNING_KEYCHAIN_PATH`    | `/tmp/build.keychain`                    | Path to the Keychain containing the certificate to sign for macOS with |
| `APPLE_SIGNING_KEYCHAIN_PROFILE` | `build`                                  | Name of the profile in the specified Keychain |


### Building on Windows

On Windows, built wheels needs to be fixed post-build to move the bundled DLLs (libzim and libicu)
next to the wrapper (Windows does not support runtime path).

After building you wheel, run

```ps
python setup.py repair_win_wheel --wheel=dist/xxx.whl --destdir wheels\
```

Similarily, if you install as editable (`pip install -e .`), you need to place those DLLs at the root
of the repo.

```ps
Move-Item -Force -Path .\libzim\*.dll -Destination .\
```

### Examples

##### Default: downloading and bundling most appropriate libzim release binary

```sh
python3 -m build
```

#### Using system libzim (brew, debian or manually installed) - not bundled

```sh
# using system-installed C++ libzim
brew install libzim  # macOS
apt-get install libzim-devel  # debian
dnf install libzim-dev  # fedora
USE_SYSTEM_LIBZIM=1 python3 -m build --wheel

# using a specific C++ libzim
USE_SYSTEM_LIBZIM=1 \
CFLAGS="-I/usr/local/include" \
LDFLAGS="-L/usr/local/lib"
DYLD_LIBRARY_PATH="/usr/local/lib" \
LD_LIBRARY_PATH="/usr/local/lib" \
python3 -m build --wheel
```

#### Other platforms

On platforms for which there is no [official binary](https://download.openzim.org/release/libzim/) available, you'd have to [compile C++ libzim from source](https://github.com/openzim/libzim) first then either use `DONT_DOWNLOAD_LIBZIM` or `USE_SYSTEM_LIBZIM`.


## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0) or later, see
[LICENSE](LICENSE) for more details.
