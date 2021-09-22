#!/usr/bin/env python3


"""
A description file for invoke (https://www.pyinvoke.org/)
"""

from invoke import task


@task
def build_ext(c):
    c.run("python setup.py build_ext -i")


@task
def test(c):
    c.run(f"python -m pytest --color=yes --ff")


@task
def clean(c):
    c.run("rm -rf build")
    c.run("rm *.so")


@task
def install_dev(c):
    c.run("pip install -r requirements-dev.txt")


@task
def lint(c):
    c.run("isort .")
    c.run("black .")
    c.run("flake8 .")


if __name__ == "__main__":
    print(
        """\
This file is not intended to be directly run.
Install invoke and run the `invoke` command line.
"""
    )
