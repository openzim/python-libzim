#!/usr/bin/env python3


"""
A description file for invoke (https://www.pyinvoke.org/)
"""

import inspect

# temp local fix for https://github.com/pyinvoke/invoke/issues/891
if not hasattr(inspect, "getargspec"):
    inspect.getargspec = inspect.getfullargspec

from invoke import task


@task
def download_libzim(c, version=""):
    """download C++ libzim binary"""
    env = f"LIBZIM_DL_VERSION={version}" if version else ""
    c.run(f"{env} python setup.py download_libzim")


@task
def build_ext(c):
    """build extension to use locally (devel, tests)"""
    c.run("PROFILE=1 python setup.py build_ext -i")


@task
def test(c):
    """run test suite"""
    c.run("python -m pytest --color=yes --ff -x .")


@task
def coverage(c):
    """generate coverage report"""
    c.run(
        "python -m pytest --color=yes "
        "--cov=libzim --cov-config=.coveragerc "
        "--cov-report=term --cov-report term-missing ."
    )


@task
def clean(c):
    """remove build folder and generated files"""
    c.run("rm -rf build")
    c.run("rm -f *.so")
    c.run("rm -rf include")
    c.run("rm -rf libzim/libzim.{so,dylib} libzim/libzim.so.* libzim/libzim.*.dylib")


@task
def install_dev(c):
    """install dev requirements"""
    c.run("pip install -r requirements-dev.txt")


@task
def check(c):
    """run Q/A checks"""
    c.run("isort --check-only .")
    c.run("black --check .")
    c.run('echo "one pass for show-stopper syntax errors or undefined names"')
    c.run("flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics")
    c.run('echo "one pass for small stylistic things"')
    c.run("flake8 . --count --statistics")


@task
def lint(c):
    """Apply Q/A linting"""
    c.run("isort .")
    c.run("black .")
    c.run("flake8 .")


if __name__ == "__main__":
    print(
        "This file is not intended to be directly run.\n"
        "Install invoke and run the `invoke` command line."
    )
