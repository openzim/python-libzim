## Developer Documentation

**These instructions are for developers working on the `python-libzim`
  source code itself.** *If you are simply a user of the library and
  you don't intend to change its internal source code, follow the User
  Documentation instructions above instead.*

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

## Common Tasks

### Run Linters & Tests

```bash
# Check format and linting
invoke check
# Autoformat and import sorting
invoke lint
# Typecheck with mypy (optional)
mypy .
# Run tests
invoke test
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

