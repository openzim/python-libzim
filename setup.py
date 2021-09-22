#!/usr/bin/env python3
"""
python-libzim (the openzim/libzim bindings for Python)

The project is compiled in two steps:

 1. Cython: compile the cython format files (.pyx, .pyd) to C++ (.cpp and .h)
 2. Cythonize: compile the generated C++ to a python-importable binary extension .so

The Cython and Cythonize compilation is done automatically with setup.py:

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
 $ export LD_LIBRARY_PATH+=":/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"
"""
import os
import platform
from pathlib import Path
from ctypes.util import find_library

from setuptools import setup, Extension
from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as build_ext

BASE_DIR = Path(__file__).parent
LIBZIM_INCLUDE_DIR = "include"  # the libzim C++ header src dir (containing zim/*.h)
LIBZIM_LIBRARY_DIR = "lib"  # the libzim .so binary lib dir (containing libzim.so)
LIBZIM_DYLIB = "libzim.{ext}".format(
    ext="dylib" if platform.system() == "Darwin" else "so"
)
# set PROFILE env to `1` to enable profile info on build (used for coverage reporting)
PROFILE = os.getenv("PROFILE", "") == "1"


class fixed_build_ext(build_ext):
    """Workaround for rpath bug in distutils for OSX."""

    def finalize_options(self):
        super().finalize_options()
        # Special treatment of rpath in case of OSX, to work around python
        # distutils bug 36353. This constructs proper rpath arguments for clang.
        # See https://bugs.python.org/issue36353
        if platform.system() == "Darwin":
            for path in self.rpath:
                for ext in self.extensions:
                    ext.extra_link_args.append("-Wl,-rpath," + path)
            self.rpath[:] = []


include_dirs = ["libzim"]
library_dirs = []
# Check for the CPP Libzim library headers in expected directory
if (BASE_DIR / LIBZIM_INCLUDE_DIR / "zim" / "zim.h").exists() and
   (BASE_DIR / LIBZIM_LIB_DIR / LIBZIM_DYLIB).exists():
    print(
        f"Found lizim library and headers in local directory.\n"
        f"We will use them to compile python-libzim.\n"
        f"Hint : If you don't want to use them (and use \"system\" installed one), remove them."
    )
    include_dirs.append("include")
    library_dirs = ["lib"]
else:
    # Check for library.
    if not find_library("zim"):
        print(
            "[!] The libzim library cannot be found.\n"
            "Please verify that the library is correctly installed of and can be found."
        )
        sys.exit(1)
    print("Using system installed library. We are assuming CFLAGS/LDFLAGS are correctly set.")


wrapper_extension = Extension(
    name="libzim",
    sources=["libzim/libzim.pyx", "libzim/libwrapper.cpp"],
    include_dir=include_dirs,
    libraries=["zim"],
    library_dirs=library_dirs,
    extra_compile_args=["-std=c++11", "-Wall", "-Wextra"],
    language="c++",
    define_macros=[("CYTHON_TRACE", "1"), ("CYTHON_TRACE_NOGIL", "1")]
    if PROFILE
    else [],
)

compiler_directives = {"language_level": "3"}
if PROFILE:
    compiler_directives.update({"linetrace": "True"})

setup(
    # Content
    cmdclass={"build_ext": fixed_build_ext},
    ext_modules=cythonize([wrapper_extension], compiler_directives=compiler_directives),
)
