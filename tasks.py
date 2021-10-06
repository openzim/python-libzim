#!/usr/bin/env python3


"""
A description file for invoke (https://www.pyinvoke.org/)
"""

from invoke import task

MAX_LINE_LENGTH = 88


@task
def build_ext(c):
    c.run("PROFILE=1 python setup.py build_ext -i")


@task
def test(c):
    c.run(
        "python -m pytest --color=yes --ff "
        "--cov=libzim --cov-config=.coveragerc "
        "--cov-report=term --cov-report term-missing ."
    )


@task
def clean(c):
    c.run("rm -rf build")
    c.run("rm *.so")


@task
def install_dev(c):
    c.run("pip install -r requirements-dev.txt")


@task
def check(c):
    c.run("isort --profile=black --check-only .")
    c.run("black --check .")
    c.run('echo "one pass for show-stopper syntax errors or undefined names"')
    c.run("flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics")
    c.run('echo "one pass for small stylistic things"')
    c.run(f"flake8 . --count --max-line-length={MAX_LINE_LENGTH} --statistics")


@task
def lint(c):
    c.run("isort --profile=black .")
    c.run("black .")
    c.run("flake8 .")


if __name__ == "__main__":
    print(
        "This file is not intended to be directly run.\n"
        "Install invoke and run the `invoke` command line."
    )
