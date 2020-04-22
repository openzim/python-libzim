
# python-libzim

> The Python bindings for [`libzim`](https://github.com/openzim/libzim).

```bash
# Install from PyPI: https://pypi.org/project/libzim/
pip3 install libzim
```

This library allows you to interact with `.zim` files via Python.

It just provides a shallow Python interface on top of the  `libzim` C++ library (maintained by [OpenZIM](https://github.com/openzim)). The versions are pinned between the two packages (`python-libzim==6.1.1 <=> libzim==6.1.1`).

It is primarily used by [`sotoki`](https://github.com/openzim/sotoki).

## Quickstart

```python3
# Writer API
from libzim import ZimCreator, ZimArticle, ZimBlob, ...

with zimcreator('test.zim') as zc:
    zc.add_article(ZimArticle(...))
```

```python3
# Reader API (coming soon...)
from libzim import zimreader

with zimreader('test.zim') as zr:
    for article in zr.namespace('A'):
        print(article.url, article.title, article.content.decode())
```

---

## User Documentation

### Setup: Ubuntu/Debian `x86_64` (Recommended)

Install the python `libzim` package from PyPI.
```bash
pip3 install libzim
python -c "from libzim import ZimArticle"
```

The `x86_64` linux wheel automatically includes the `libzim.so` dylib and headers, but other platforms may need to install `libzim` and its headers manually.

#### Installing the `libzim` dylib and headers manually

```bash
# Install the `libzim` dylib and headers from a pre-built release
LIBZIM_VERSION=6.1.1
LIBZIM_RELEASE=libzim_linux-x86_64-$LIBZIM_VERSION
LIBZIM_LIBRARY_PATH=lib/x86_64-linux-gnu/libzim.so.$LIBZIM_VERSION
LIBZIM_INCLUDE_PATH=include/zim

wget -qO- https://download.openzim.org/release/libzim/$LIBZIM_RELEASE.tar.gz | tar -xz -C .
sudo mv $LIBZIM_RELEASE/$LIBZIM_LIBRARY_PATH lib/libzim.so
sudo mv $LIBZIM_RELEASE/$LIBZIM_INCLUDE_PATH include/zim
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
sudo ldconfig
```
If a pre-built release is not available for your platform, you can also [install `libzim` from source](https://github.com/openzim/libzim#dependencies).


## Setup: Docker (Optional)

```bash
docker build . --tag openzim:python-libzim

# Run a custom script inside the container
docker run -it openzim:python-libzim ./some_example_script.py

# Or use the python repl interactively
docker run -it openzim:python-libzim
>>> from libzim import ZimCreator, ZimArticle, ZimBlob
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

git clone https://github.com/openzim/python-libzim
cd python-libzim
python setup.py build_ext
pipenv install --dev
pipenv run pip install -e .
pipenv run python -c "from libzim import ZimArticle"
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
$ python -c "from libzim import ZimArticle"

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
export CFLAGS="-I/tmp/libzim_linux-x86_64-6.1.1/include"
export LDFLAGS="-L/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
python setup.py build_ext
python setup.py install
```

---

## Examples

```python3
from libzim import zimcreator, ZimArticle, ZimBlob, ZimCreator

class ZimTestArticle(ZimArticle):
    content = '''<!DOCTYPE html> 
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical</title>
                </head>
                <h1> ñññ Hello, it works ñññ </h1></html>'''

    def __init__(self):
        ZimArticle.__init__(self)

    def is_redirect(self):
        return False

    def get_url(self):
        return "A/Monadical_SAS"

    def get_title(self):
        return "Monadical SAS"
    
    def get_mime_type(self):
        return "text/html"
    
    def get_filename(self):
        return ""
    
    def should_compress(self):
        return True

    def should_index(self):
        return True

    def get_data(self):
        return ZimBlob(self.content.encode('UTF-8'))


# Set up a ZimCreator instance to collect articles into one .zim file
zim_creator = ZimCreator(
    'test.zim',
    main_page="welcome",
    index_language="eng",
    min_chunk_size=2048,
)
zim_creator.update_metadata(
    name='Hola',
    title='Test Zim',
    publisher='Monadical',
    creator='python-libzim',
    description='Created in python', 
)

# Write the test article to .zim file by adding it via the ZimCreator
zim_creator.add_article(ZimTestArticle())

# ZimCreator.finalize() must be called in order to save the writes to disk
zim_creator.finalize()

# Alternatively, use the context manager form of ZimCreator
#   to avoid having to call .finalize() manually:
with zimcreator('test.zim', main_index="welcome", ...) as zc:
    zc.add_article(article)
    if not zc.mandatory_metadata_ok():
        zc.update_metadata(creator='python-libzim',
                                    description='Created in python',
                                    name='Hola',
                                    publisher='Monadical',
                                    title='Test Zim')
    # zc.finalize() is called automatically when context manager exits
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
