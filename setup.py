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

 - Compile and install libzim from source : https://github.com/openzim/libzim
 - Download a full prebuilt release (if one exists for your platform):
   https://download.openzim.org/release/libzim/
 - Installed a packaged version of libzim :
   . `apt-get install libzim-devel`
   . `dnf install libzim-dev`

Either place the `libzim.so` and `zim/*.h` files in `./lib/` and `./include/`,
   or set these environment variables to use custom libzim header and dylib paths:

 $ export CFLAGS="-I/tmp/libzim_linux-x86_64-6.1.1/include"
 $ export LDFLAGS="-L/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"
 $ export LD_LIBRARY_PATH+=":/tmp/libzim_linux-x86_64-6.1.1/lib/x86_64-linux-gnu"

If you have installed libzim from the packages, you probably don't have anything to do
on environment variables side.
"""

import os
import platform
import sys
from ctypes.util import find_library
from pathlib import Path

from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as build_ext
from setuptools import Extension, setup

# Avoid running cythonize on `setup.py clean` and similar
SKIP_BUILD_CMDS = ["clean", "--help", "egg_info", "--version"]

base_dir = Path(__file__).parent

# Check if we need profiling (env var PROFILE set to `1`, used for coverage reporting)
compiler_directives = {"language_level": "3"}
if os.getenv("PROFILE", "") == "1":
    define_macros = [("CYTHON_TRACE", "1"), ("CYTHON_TRACE_NOGIL", "1")]
    compiler_directives.update(linetrace=True)
else:
    define_macros = []

if platform.system() == "Darwin":

    class fixed_build_ext(build_ext):
        """Workaround for rpath bug in distutils for OSX."""

        def finalize_options(self):
            super().finalize_options()
            # Special treatment of rpath in case of OSX, to work around python
            # distutils bug 36353. This constructs proper rpath arguments for clang.
            # See https://bugs.python.org/issue36353
            for path in self.rpath:
                for ext in self.extensions:
                    ext.extra_link_args.append("-Wl,-rpath," + path)
            self.rpath[:] = []

    cmdclass = {"build_ext": fixed_build_ext}
else:
    cmdclass = {"build_ext": build_ext}


def cython_ext_module():
    dyn_lib_ext = "dylib" if platform.system() == "Darwin" else "so"
    include_dirs = ["libzim"]
    library_dirs = []
    # Check for the CPP Libzim library headers in expected directory
    header_file = base_dir / "include" / "zim" / "zim.h"
    lib_file = base_dir / "lib" / f"libzim.{dyn_lib_ext}"
    if header_file.exists() and lib_file.exists():
        print(
            "Found lizim library and headers in local directory. "
            "Will use them to compile python-libzim.\n"
            "Hint : If you don't want to use them "
            "(and use “system” installed one), remove them."
        )
        include_dirs.append("include")
        library_dirs = ["lib"]
    elif "clean" not in sys.argv:
        # Check for library.
        if not find_library("zim"):
            print(
                "[!] The libzim library cannot be found.\n"
                "Please verify it is correctly installed and can be found."
            )
            sys.exit(1)
        print(
            "Using system installed library; Assuming CFLAGS/LDFLAGS are correctly set."
        )

    wrapper_extension = Extension(
        name="libzim",
        sources=["libzim/libzim.pyx", "libzim/libwrapper.cpp"],
        include_dirs=include_dirs,
        libraries=["zim"],
        library_dirs=library_dirs,
        extra_compile_args=["-std=c++11", "-Wall", "-Wextra"],
        language="c++",
        define_macros=define_macros,
    )
    return cythonize([wrapper_extension], compiler_directives=compiler_directives)


if len(sys.argv) == 2 and sys.argv[1] in SKIP_BUILD_CMDS:
    ext_modules = None
else:
    ext_modules = cython_ext_module()

setup(
    # Content
    cmdclass=cmdclass,
    ext_modules=ext_modules,
)
