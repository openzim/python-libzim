
# python-libzim

The Python bindings for [`libzim`](https://github.com/openzim/libzim).

This library allows you to interact with `.zim` files via Python.

It just provides a shallow Python interface on top of the  `libzim` C++ library (maintained by [OpenZIM](https://github.com/openzim)).

It is primarily used by [`sotoki`](https://github.com/openzim/sotoki).

[![](https://img.shields.io/pypi/v/libzim.svg)](https://pypi.python.org/pypi/libzim)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Installation

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

See [example](examples/basic_writer.py) for a basic usage of the writer API.


---

## User Documentation

### Setup: Ubuntu/Debian and macOS `x86_64` (Recommended)

Install the python `libzim` package from PyPI.

```bash
pip3 install libzim
```

The `x86_64` linux and macOS wheels automatically includes the `libzim.(so|dylib)` dylib and headers, but other platforms may need to install `libzim` and its headers manually.


### Installing the `libzim` dylib and headers manually

If you are not on a linux or macOS `x86_64` platform, you will have to install libzim manually.

Either by get a prebuilt binary at https://download.openzim.org/release/libzim
or [compile `libzim` from source](https://github.com/openzim/libzim).

If you have not installed libzim in standard directory, you will have to set `LD_LIBRARY_PATH` to allow python to find the library :

Assuming you have extracted (or installed) the library if LIBZIM_DIR:


```bash
export LD_LIBRARY_PATH="${LIBZIM_DIR}/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
```

## Setup: Docker (Optional)

```bash
docker build . --tag openzim:python-libzim

# Run a custom script inside the container
docker run -it openzim:python-libzim ./some_example_script.py

# Or use the python repl interactively
docker run -it openzim:python-libzim
>>> import libzim
```

---

## Developer Documentation

**These instructions are for developers working on the `python-libzim` source code itself.** *If you are simply a user of the library and you don't intend to change its internal source code, follow the User Documentation instructions above instead.*

### Setup: Ubuntu/Debian

*Note: Make sure you've installed `libzim` dylib + headers first (see above).*

```bash
apt install coreutils wget git ca-certificates \
        g++ pkg-config libtool automake autoconf make meson ninja-build \
        liblzma-dev zlib1g-dev libicu-dev libgumbo-dev libmagic-dev

pip3 install --upgrade pip pipenv

export CFLAGS="-I${LIBZIM_DIR}/include"
export LDFLAGS="-L${LIBZIM_DIR}/lib/x86_64-linux-gnu"
git clone https://github.com/openzim/python-libzim
cd python-libzim
python setup.py build_ext
pipenv install --dev
pipenv run pip install -e .
```

### Setup: Docker

```bash
docker build . -f Dockerfile.dev --tag openzim:python-libzim-dev

docker run -it openzim:python-libzim-dev ./some_example_script.py

docker run -it openzim:python-libzim-dev
$ black . && flake8 . && pytest .
$ pipenv install --dev <newpackagehere>
$ python setup.py build_ext
$ python setup.py sdist bdist_wheel
$ python setup.py install
$ python -c "import libzim"

```

---

## Common Tasks

### Run Linters & Tests

```bash
# Autoformat code with black
black --exclude=setup.py .
# Lint and check for errors with flake8
flake8 --exclude=setup.py .
# Typecheck with mypy (optional)
mypy .
# Run tests
pytest .
```

### Rebuild Cython extension during development

```bash
rm libzim/libzim.cpp
rm -Rf build
rm -Rf *.so
python setup.py build_ext
python setup.py install
```

### Build package `sdist` and `bdist_wheels` for PyPI

```bash
python setup.py build_ext
python setup.py sdist bdist_wheel

# upload to PyPI (caution: this is done automatically via Github Actions)
twine upload dist/*
```

### Use a specific `libzim` dylib and headers when compiling `python-libzim`

```bash
export CFLAGS="-I${LIBZIM_DIR}/include"
export LDFLAGS="-L${LIBZIM_DIR}/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="${LIBZIM_DIR}/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
python setup.py build_ext
python setup.py install
```
---

## Further Reading

### Related Projects
- https://github.com/openzim/sotoki
- https://framagit.org/mgautierfr/pyzim
- https://github.com/pediapress/pyzim
- https://github.com/jarondl/pyzimmer/blob/master/pyzimmer/zim_writer.py

### Research
- https://github.com/cython/cython/wiki/AutoPxd
- https://www.youtube.com/watch?v=YReJ3pSnNDo
- https://github.com/openzim/zim-tools/blob/master/src/zimrecreate.cpp
- https://github.com/cython/cython/wiki/enchancements-inherit_CPP_classes
- https://groups.google.com/forum/#!topic/cython-users/vAB9hbLMxRg

### Debugging
- https://cython.readthedocs.io/en/latest/src/userguide/debugging.html
- https://github.com/cython/cython/wiki/DebuggingTechniques
- https://stackoverflow.com/questions/2663841/python-tracing-a-segmentation-fault
- https://cython-devel.python.narkive.com/cW3Cn1th/debugging-a-segfault-in-a-cython-generated-module
- https://groups.google.com/forum/#!topic/cython-users/B_Sxj2NV1PE

### Packaging
- https://download.openzim.org/release/libzim/
- https://cibuildwheel.readthedocs.io/en/stable/faq/
- https://github.com/pypa/manylinux
- https://github.com/RalfG/python-wheels-manylinux-build/blob/master/full_workflow_example.yml
- https://packaging.python.org/guides/packaging-binary-extensions/#publishing-binary-extensions

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0) or later, see
[LICENSE](LICENSE) for more details.
