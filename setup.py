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
import platform
from pathlib import Path
from ctypes.util import find_library

from setuptools import setup, Extension
from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as build_ext

GITHUB_URL = "https://github.com/openzim/python-libzim"
BASE_DIR = Path(__file__).parent
LIBZIM_INCLUDE_DIR = 'include'   # the libzim C++ header src dir (containing zim/*.h)
LIBZIM_LIBRARY_DIR = 'lib'       # the libzim .so binary lib dir (containing libzim.so)
LIBZIM_DYLIB = 'libzim.{ext}'.format(ext='dylib' if platform.system() == 'Darwin' else 'so')


class fixed_build_ext(build_ext):
    """Workaround for rpath bug in distutils for OSX."""

    def finalize_options(self):
        super().finalize_options()
        # Special treatment of rpath in case of OSX, to work around python
        # distutils bug 36353. This constructs proper rpath arguments for clang.
        # See https://bugs.python.org/issue36353
        if platform.system() == 'Darwin':
            for path in self.rpath:
                for ext in self.extensions:
                    ext.extra_link_args.append("-Wl,-rpath," + path)
            self.rpath[:] = []


# Check for the CPP Libzim library headers in expected directory
if not (BASE_DIR / LIBZIM_INCLUDE_DIR / 'zim/zim.h').exists():
    print(
        f"[!] Warning: Couldn't find zim/*.h in ./{LIBZIM_INCLUDE_DIR}!\n"
        f"    Hint: You can install them from source from https://github.com/openzim/libzim\n"
        f"          or download a prebuilt release's headers into ./include/zim/*.h\n"
        f"          (or set CFLAGS='-I<library_path>/include')"
    )

# Check for the CPP Libzim shared library in expected directory or system paths
if not ((BASE_DIR / LIBZIM_LIBRARY_DIR / LIBZIM_DYLIB).exists() or find_library('zim')):
    print(
        f"[!] Warning: Couldn't find {LIBZIM_DYLIB} in ./{LIBZIM_LIBRARY_DIR} or system library paths!"
        f"    Hint: You can install it from source from https://github.com/openzim/libzim\n"
        f"          or download a prebuilt {LIBZIM_DYLIB} release into ./lib.\n"
        f"          (or set LDFLAGS='-L<library_path>/lib/[x86_64-linux-gnu]')"
    )

def get_long_description():
    return (BASE_DIR/'README.md').read_text()

wrapper_extension = Extension(
    name = "libzim.wrapper",
    sources = ["libzim/wrapper.pyx", "libzim/lib.cxx"],
    include_dirs=["libzim", LIBZIM_INCLUDE_DIR],
    libraries=['zim'],
    library_dirs=[LIBZIM_LIBRARY_DIR],
    extra_compile_args=["-std=c++11", "-Wall", "-Wextra"],
    language="c++",
)


setup(
# Basic information about libzim module
    name="libzim",
    version="0.1",
    url=GITHUB_URL,
    project_urls={
        'Source': GITHUB_URL,
        'Bug Tracker': f'{GITHUB_URL}/issues',
        'Changelog': f'{GITHUB_URL}/releases',
        'Documentation': f'{GITHUB_URL}/blob/master/README.md',
        'Donate': 'https://www.kiwix.org/en/support-us/',
    },
    author="Monadical Inc.",
    author_email="jdc@monadical.com",
    license="GPLv3+",
    description="A python-facing API for creating and interacting with ZIM files",
    long_description=get_long_description(),
    long_description_content_type="text/markdown",
    python_requires='>=3.6',

    # Content
    packages=["libzim"],
    cmdclass={'build_ext': fixed_build_ext},
    ext_modules=cythonize([wrapper_extension],
        compiler_directives={"language_level": "3"}
    ),

# Packaging
    include_package_data=True,
    zip_safe=False,

# Extra
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
