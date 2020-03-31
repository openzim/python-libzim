import os
from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

# Utility function to read the README file.
# Used for the long_description.  It's nice, because now 1) we have a top level
# README file and 2) it's easier to type in the README file than to put a raw
# string in below ...
def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()

setup(
    name = "python-libzim",
    version = "0.0.1",
    author = "Monadical SAS",
    author_email = "hello@monadical.com",
    description = ("A python-facing API for creating and interacting with ZIM files"),
    license = "GPLv3",
    long_description=read('README.rst'),
    ext_modules = cythonize([
        Extension("pyzim",  ["pyzim/*.pyx","pyzim/wrappers.cpp"],
                  libraries=["zim"],
                  language="c++"),
    ],
    compiler_directives={'language_level' : "2"}
    )
)
