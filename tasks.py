#!/usr/bin/env python3


"""
A description file for invoke (https://www.pyinvoke.org/)
"""

import pathlib
import platform
import re
import urllib.request

from invoke import task


@task
def download_libzim(c, version="7.2.2"):
    """download C++ libzim binary"""

    if platform.machine() != "x86_64" or platform.system() not in ("Linux", "Darwin"):
        raise NotImplementedError(f"Platform {platform.platform()} not supported")

    is_nightly = re.match(r"^\d{4}-\d{2}-\d{2}$", version)

    if not is_nightly and not re.match(r"^\d\.\d\.\d$", version):
        raise ValueError(
            f"Unrecognised version {version}. "
            "Must be either a x.x.x release or a Y-M-D date to use a nightly"
        )

    fname = pathlib.Path(
        "libzim_{os}-x86_64-{version}.tar.gz".format(
            os={"Linux": "linux", "Darwin": "macos"}.get(platform.system()),
            version=version,
        )
    )
    url = (
        f"https://download.openzim.org/nightly/{version}/{fname.name}"
        if is_nightly
        else f"https://download.openzim.org/release/libzim/{fname.name}"
    )
    print("Downloading from", url)

    with urllib.request.urlopen(url) as response, open(fname, "wb") as fh:  # nosec
        fh.write(response.read())

    # extract and remove archive
    c.run(f"tar -xvf {fname.name}")
    c.run(f"rm -vf {fname.name}")

    # remove previous install from target directories
    c.run("find ./include -not -name 'README.md' -not -name 'include' | xargs rm -rf")
    c.run("find ./lib -not -name 'README.md' -not -name 'lib' | xargs rm -rf")

    # move extracted bins and headers to expected places
    dname = fname.with_suffix("").stem
    c.run(f"mv -v {dname}/include/* ./include/")
    if platform.system() == "Linux":
        c.run(f"mv -v {dname}/lib/x86_64-linux-gnu/* ./lib/")
        c.run(f"rmdir {dname}/lib/x86_64-linux-gnu")
    else:
        c.run(f"mv -v {dname}/lib/* ./lib/")
    # remove extracted folder (should be empty)
    c.run(f"rmdir {dname}/lib {dname}/include/ {dname}")

    # add link for version-less dylib and link from root
    if platform.system() == "Darwin":
        c.run(f"ln -svf ./lib/libzim.{version[0]}.dylib .")
        c.run(f"ln -svf ./libzim.{version[0]}.dylib lib/libzim.dylib")
    else:
        c.run(f"ln -svf ./lib/libzim.so.{version[0]} .")
        c.run(f"ln -svf ./libzim.so.{version[0]} lib/libzim.so")


@task
def build_ext(c):
    c.run("PROFILE=1 python setup.py build_ext -i")


@task
def test(c):
    c.run("python -m pytest --color=yes --ff -x .")


@task
def coverage(c):
    c.run(
        "python -m pytest --color=yes "
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
    c.run("isort --check-only .")
    c.run("black --check .")
    c.run('echo "one pass for show-stopper syntax errors or undefined names"')
    c.run("flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics")
    c.run('echo "one pass for small stylistic things"')
    c.run("flake8 . --count --statistics")


@task
def lint(c):
    c.run("isort .")
    c.run("black .")
    c.run("flake8 .")


if __name__ == "__main__":
    print(
        "This file is not intended to be directly run.\n"
        "Install invoke and run the `invoke` command line."
    )
