# python-libzim

The Python bindings for [`libzim`](https://github.com/openzim/libzim)
allows you to read/write [ZIM files](https://openzim.org) via
Python. It provides a shallow Python interface on top of the `libzim`
C++ library.

It is primarily used in openZIM scrapers like for example
[`Sotoki`](https://github.com/openzim/sotoki) or
[`Youtube2zim`](https://github.com/openzim/youtube2zim).

Read [CONTRIBUTING.md](./CONTRIBUTING.md) to know more about
Python-libzim development.

[![](https://img.shields.io/pypi/v/libzim.svg)](https://pypi.python.org/pypi/libzim)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Installation

PyPI package is bundled with a recent version of the libzim for macOS
and GNU/Linux (x86_64 architecture). For other OSes, the libzim
version 6.x.x has to be compiled manually, See [Setup
hints](#setup-hints) to know more.

```bash
# Install from PyPI: https://pypi.org/project/libzim/
pip3 install libzim
```

## Quickstart

### Reader API

```python3
from libzim.reader import File

f = File("test.zim")
article = f.get_article("article/url.html")
print(article.url, article.title)
if not article.is_redirect():
    print(article.content)
```

### Write API

See [example](examples/basic_writer.py) for a basic usage of the
writer API.

## Setup hints

### Installing the `libzim` dylib and headers manually

If you have to install the libzim manually, you will have to [compile
`libzim` from source](https://github.com/openzim/libzim).

If you have not installed libzim in standard directory, you will have
to set `LD_LIBRARY_PATH` to allow python to find the library. Assuming
you have extracted (or installed) the library if LIBZIM_DIR:

```bash
export LD_LIBRARY_PATH="${LIBZIM_DIR}/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
```

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0) or later, see
[LICENSE](LICENSE) for more details.
