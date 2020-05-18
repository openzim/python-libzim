#!/usr/bin/env python3
"""
python-libzim (the openzim/libzim bindings for Python)

The project is compiled in two steps:

 1. Cython: compile the cython format files (.pyx, .pyd) to C++ (.cpp and .h)
 2. Cythonize: compile the generated C++ to a python-importable binary extension .so

The Cython and Cythonize compilation is done automatically during packaging with setup.py:

 $ python3 setup.py build_ext
 $ python3 setup.py sdist bdist_wheel


To compile or run this project, you must first get the libzim headers & binary:

 - You can get the headers here and build and install the binary from source:
   https://github.com/openzim/libzim

 - Or you can download a full prebuilt release (if one exists for your platform):
   https://download.openzim.org/release/libzim/

Either place the `libzim.so` and `zim/*.h` files in `./lib/` and `./include/`,
   or set these environment variables to use custom libzim header and dylib paths:

 $ export CFLAGS="-I/tmp/libzim_linux-x86_64-6.1.1/include"
 $ export LDFLAGS="-L/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"
 $ export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"
"""
from pathlib import Path
from ctypes.util import find_library

from setuptools import setup, Extension
from Cython.Build import cythonize


PACKAGE_NAME = "libzim_wrapper"
VERSION = "0.0.1"  # pegged to be the same version as libzim since they are always released together
LICENSE = "GPLv3+"
DESCRIPTION = "A python-facing API for creating and interacting with ZIM files"
AUTHOR = "Monadical Inc."
AUTHOR_EMAIL = "jdc@monadical.com"
GITHUB_URL = "https://github.com/openzim/python-libzim"

BASE_DIR = Path(__file__).parent
BINDINGS_CYTHON_DIR = 'libzim'   # the cython binding source dir (containing .pyx, .pyd, etc.)
LIBZIM_INCLUDE_DIR = 'include'   # the libzim C++ header src dir (containing zim/*.h)
LIBZIM_LIBRARY_DIR = 'lib'       # the libzim .so binary lib dir (containing libzim.so)


# Check for the CPP Libzim library headers in expected directory
if not (BASE_DIR / LIBZIM_INCLUDE_DIR / 'zim/zim.h').exists():
    print(
        f"[!] Warning: Couldn't find zim/*.h in ./{LIBZIM_INCLUDE_DIR}!\n"
        f"    Hint: You can install them from source from https://github.com/openzim/libzim\n"
        f"          or download a prebuilt release's headers into ./include/zim/*.h\n"
        f"          (or set CFLAGS='-I/tmp/libzim_linux-x86_64-{VERSION}/include')"
    )

# Check for the CPP Libzim shared library in expected directory or system paths
if not ((BASE_DIR / LIBZIM_LIBRARY_DIR / 'libzim.so').exists() or find_library('zim')):
    print(
        f"[!] Warning: Couldn't find libzim.so in ./{LIBZIM_LIBRARY_DIR} or system library paths!"
        f"    Hint: You can install it from source from https://github.com/openzim/libzim\n"
        f"          or download a prebuilt zimlib.so release into ./lib.\n"
        f"          (or set LDFLAGS='-L/tmp/libzim_linux-x86_64-{VERSION}/lib/x86_64-linux-gnu')"
    )

setup(
    name=PACKAGE_NAME,
    version=VERSION,
    url=GITHUB_URL,
    project_urls={
        'Source': GITHUB_URL,
        'Bug Tracker': f'{GITHUB_URL}/issues',
        'Changelog': f'{GITHUB_URL}/releases',
        'Documentation': f'{GITHUB_URL}/blob/master/README.md',
        'Donate': 'https://www.kiwix.org/en/support-us/',
    },
    author=AUTHOR,
    author_email=AUTHOR_EMAIL,
    license=LICENSE,
    description=DESCRIPTION,
    long_description=(BASE_DIR / 'README.md').read_text(),
    long_description_content_type="text/markdown",
    python_requires='>=3.6',
    include_package_data=True,
    ext_modules=cythonize(
        [
            Extension(
                "libzim_wrapper",
                sources=[
                    f"{BINDINGS_CYTHON_DIR}/*.pyx",
                    f"{BINDINGS_CYTHON_DIR}/lib.cxx",
                ],
                include_dirs=[
                    BINDINGS_CYTHON_DIR,
                    LIBZIM_INCLUDE_DIR,
                ],
                libraries=[
                    'zim',
                ],
                library_dirs=[
                    LIBZIM_LIBRARY_DIR,
                ],
                extra_compile_args=[
                    "-std=c++11",
                    "-Wall",
                    "-Wextra",
                ],
                language="c++",
            )
        ],
        compiler_directives={"language_level" : "3"},
    ),
    zip_safe=False,
    classifiers=[
        "Development Status :: 3 - Alpha",

        "Topic :: Utilities",
        "Topic :: Software Development :: Libraries",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Archiving",
        "Topic :: System :: Archiving :: Compression",
        "Topic :: System :: Archiving :: Mirroring",
        "Topic :: System :: Archiving :: Backup",
        "Topic :: Internet :: WWW/HTTP",
        "Topic :: Internet :: WWW/HTTP :: Indexing/Search",
        "Topic :: Sociology :: History",

        "Intended Audience :: Developers",
        "Intended Audience :: Education",
        "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "Intended Audience :: System Administrators",
        
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        # "Typing :: Typed",

        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Natural Language :: English",
        "Operating System :: OS Independent",
    ],
)
