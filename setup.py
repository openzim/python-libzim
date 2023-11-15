#!/usr/bin/env python3

"""python-libzim (openZIM/libzim binding for Python)

The project is compiled in two steps:

 1. Cython: compile the cython format files (.pyx, .pyd) to C++ (.cpp and .h)
 2. Cythonize: compile the generated C++ to a python-importable binary extension .so

The Cython and Cythonize compilation is done automatically by the build backend"""

import os
import pathlib
import platform as sysplatform
import re
import shutil
import subprocess
import sys
import sysconfig
import tarfile
import urllib.request
from ctypes.util import find_library
from pathlib import Path
from typing import Optional, Tuple

from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as build_ext
from setuptools import Command, Extension, setup


class Config:
    libzim_dl_version: str = os.getenv("LIBZIM_DL_VERSION", "9.0.0")
    use_system_libzim: bool = bool(os.getenv("USE_SYSTEM_LIBZIM", False))
    download_libzim: bool = not bool(os.getenv("DONT_DOWNLOAD_LIBZIM", False))

    # toggle profiling for coverage report in Cython
    profiling: bool = os.getenv("PROFILE", "") == "1"

    # macOS signing
    should_sign_apple: bool = bool(os.getenv("SIGN_APPLE", False))
    apple_signing_identity: str = os.getenv("APPLE_SIGNING_IDENTITY")
    apple_signing_keychain: str = os.getenv("APPLE_SIGNING_KEYCHAIN_PATH")
    apple_signing_keychain_profile: str = os.getenv("APPLE_SIGNING_KEYCHAIN_PROFILE")

    supported_platforms = {
        "Darwin": ["x86_64", "arm64"],
        "Linux": ["x86_64", "aarch64"],
        "Linux-musl": ["x86_64", "aarch64"],
    }

    base_dir: pathlib.Path = Path(__file__).parent

    # Avoid running cythonize on `setup.py clean` and similar
    buildless_commands: Tuple[str] = (
        "clean",
        "--help",
        "egg_info",
        "--version",
        "download_libzim",
    )

    @property
    def libzim_major(self) -> str:
        # assuming nightlies are for version 8.x
        return 9 if self.is_nightly else self.libzim_dl_version[0]

    @property
    def found_libzim(self) -> str:
        return find_library("zim")

    @property
    def is_latest_nightly(self) -> bool:
        """will use redirect to latest available nightly"""
        return self.libzim_dl_version == "nightly"

    @property
    def is_nightly(self) -> bool:
        return self.is_latest_nightly or re.match(
            r"\d{4}-\d{2}-\d{2}", self.libzim_dl_version
        )

    @property
    def platform(self) -> str:
        """Platform building for: Darwin, Linux"""
        return sysplatform.system()

    @property
    def platform_libc(self) -> str:
        """Platform adjusted for libc variant: Darwin, Linux, Linux-musl"""
        if self.platform == "Linux" and self.is_musl:
            return "Linux-musl"
        return self.platform

    @property
    def arch(self) -> str:
        # macOS x86_64|arm64 - linux x86_64|aarch64

        # when using cibuildwheel on macOS to cross-compile,
        # `_PYTHON_HOST_PLATFORM` contains
        # a platform string like macosx-11.0-arm64
        # we extract the cross-compile arch from it
        return (
            os.getenv("_PYTHON_HOST_PLATFORM", "").rsplit("-", 1)[-1]
            or sysplatform.machine()
        )

    def check_platform(self):
        if (
            self.platform_libc not in self.supported_platforms
            or self.arch not in self.supported_platforms[self.platform_libc]
        ):
            raise NotImplementedError(
                f"Platform {self.platform_libc}/{self.arch} is not supported."
            )

    @property
    def libzim_fname(self):
        """binary libzim dynamic library fname (platform dependent)"""
        # assuming we'll always link to same major

        return {
            "Darwin": f"libzim.{self.libzim_major}.dylib",
            "Linux": f"libzim.so.{self.libzim_major}",
        }[self.platform]

    @property
    def is_musl(self) -> bool:
        """whether running on a musl system (Alpine)"""
        ps = subprocess.run(
            ["/usr/bin/env", "ldd", "--version"], capture_output=True, text=True
        )
        try:
            return "musl libc" in ps.stderr.splitlines()[0]
        except Exception:
            return False

    @property
    def wants_universal(self) -> bool:
        """whether requesting a macOS universal build"""
        return self.platform == "Darwin" and sysconfig.get_platform().endswith(
            "universal2"
        )

    def get_download_filename(self, arch: Optional[str] = None) -> str:
        """filename to download to get binary libzim for platform/arch"""
        arch = arch or self.arch

        lzplatform = {"Darwin": "macos", "Linux": "linux"}.get(self.platform)

        variant = ""
        if self.platform == "Linux":
            variant = "-musl" if self.is_musl else "-bionic"

        if self.is_latest_nightly:
            version_suffix = ""
        else:
            version_suffix = f"-{self.libzim_dl_version}"

        return pathlib.Path(
            f"libzim_{lzplatform}-{arch}{variant}{version_suffix}.tar.gz"
        ).name

    def download_to_dest(self):
        """download expected libzim binary into libzim/ and libzim/include/ folders"""
        self.check_platform()
        if self.wants_universal:
            folders = {}
            for arch in self.supported_platforms["Darwin"]:
                folders[arch] = self._download_and_extract(
                    self.get_download_filename(arch)
                )

            try:
                # duplicate x86_64 tree as placeholder (removing first)
                folder = folders["x86_64"].with_name(
                    folders["x86_64"].name.replace("x86_64", "universal")
                )
                shutil.rmtree(folder, ignore_errors=True)
                shutil.copytree(
                    folders["x86_64"],
                    folder,
                    symlinks=True,
                    ignore_dangling_symlinks=True,
                )
                # delete libzim from copied tree
                dest = folder / "lib" / self.libzim_fname
                dest.unlink()
                # create universal from all archs
                subprocess.run(
                    ["/usr/bin/env", "lipo"]
                    + [
                        str(folder / "lib" / self.libzim_fname)
                        for folder in folders.values()
                    ]
                    + ["-output", str(dest), "-create"],
                    check=True,
                )
            finally:
                # clean-up temp folders
                for _folder in folders.values():
                    shutil.rmtree(_folder, ignore_errors=True)
        else:
            folder = self._download_and_extract(self.get_download_filename())

        self._install_from(folder)

    def _download_and_extract(self, filename: str) -> pathlib.Path:
        """folder it downloaded and extracted libzim dist to"""

        fpath = self.base_dir / filename
        source_url = "http://download.openzim.org/release/libzim"
        if self.is_latest_nightly:
            source_url = "http://download.openzim.org/nightly"
        elif self.is_nightly:
            source_url = f"http://download.openzim.org/nightly/{self.libzim_dl_version}"
        url = f"{source_url}/{fpath.name}"

        # download a local copy if none present
        if not fpath.exists():
            print(f"> from {url}")
            with urllib.request.urlopen(url) as response, open(  # nosec
                fpath, "wb"
            ) as fh:  # nosec
                fh.write(response.read())
        else:
            print(f"> reusing local file {fpath}")

        print("> extracting archive")
        # extract into current folder (all files are inside an in-tar folder)
        shutil.unpack_archive(fpath, self.base_dir, "gztar")

        # nightly have different download name and extracted folder name as it
        # uses a redirect
        if self.is_latest_nightly:
            tar = tarfile.open(fpath)
            folder = pathlib.Path(pathlib.Path(tar.firstmember.name).parts[0])
        else:
            folder = fpath.with_name(fpath.name.replace(".tar.gz", ""))

        return folder

    def _install_from(self, folder: pathlib.Path):
        """move headers and libzim binary from dist folder to expected location"""
        libzim_dir = self.base_dir / "libzim"

        # remove existing headers if present
        self.base_dir.joinpath("include").mkdir(parents=True, exist_ok=True)
        shutil.rmtree(self.base_dir / "include" / "zim", ignore_errors=True)

        # copy new zim headers
        shutil.move(folder / "include" / "zim", self.base_dir / "include" / "zim")

        # copy new libs
        for fpath in folder.joinpath("lib").rglob("libzim.*"):
            print(f"{fpath} -> {libzim_dir / fpath.name}")
            os.replace(fpath, libzim_dir / fpath.name)

        # remove temp folder
        shutil.rmtree(folder, ignore_errors=True)
        assert self.base_dir.joinpath("include", "zim", "zim.h").exists()

        if config.platform == "Darwin":
            print("> ensure libzim is notarized")
            spctl = subprocess.run(
                [
                    "/usr/bin/env",
                    "spctl",
                    "-a",
                    "-v",
                    "-t",
                    "install",
                    str(self.base_dir / "libzim" / config.libzim_fname),
                ],
                check=False,
            )
            if spctl.returncode != 0:
                print(
                    "libzim binary is not notarized! Not an official release?",
                    file=sys.stderr,
                )

    def cleanup(self):
        """removes created files to prevent re-run issues"""
        # we downloaded libzim, so we must remove it
        if self.download_libzim:
            print("removing downloaded libraries")
            for fpath in self.dylib_file.parent.glob("*.[dylib|so]*"):
                print(">", fpath)
                fpath.unlink(missing_ok=True)
            if self.header_file.parent.exists():
                print("removing downloaded headers")
                shutil.rmtree(self.header_file.parent, ignore_errors=True)

    @property
    def header_file(self) -> pathlib.Path:
        return self.base_dir / "include" / "zim" / "zim.h"

    @property
    def dylib_file(self) -> pathlib.Path:
        return self.base_dir / "libzim" / self.libzim_fname

    @property
    def can_sign_apple(self) -> bool:
        return all(
            [
                self.platform == "Darwin",
                self.apple_signing_identity,
                self.apple_signing_keychain,
                self.apple_signing_keychain_profile,
                self.should_sign_apple,
            ]
        )


config = Config()


def get_cython_extension():
    define_macros = []
    compiler_directives = {"language_level": "3"}

    if config.profiling:
        define_macros += [("CYTHON_TRACE", "1"), ("CYTHON_TRACE_NOGIL", "1")]
        compiler_directives.update(linetrace=True)

    include_dirs = []
    library_dirs = []
    runtime_library_dirs = []

    if config.use_system_libzim:
        if not config.found_libzim:
            raise EnvironmentError(
                "[!] The libzim library cannot be found.\n"
                "Please verify it is correctly installed and can be found."
            )
        print(
            "Using found library at {config.found_libzim}. "
            "Adjust CFLAGS/LDFLAGS if needed"
        )
    else:
        if config.download_libzim:
            print("Downloading libzim. Set `DONT_DOWNLOAD_LIBZIM` not to.")
            config.download_to_dest()

        # Check for the CPP Libzim library headers in expected directory
        if not config.header_file.exists() or not config.dylib_file.exists():
            raise EnvironmentError(
                "Unable to find a local copy of libzim "
                f"at {config.header_file} and {config.dylib_file}"
            )

        print("Using local libzim binary. Set `USE_SYSTEM_LIBZIM` otherwise.")
        include_dirs.append("include")
        library_dirs = ["libzim"]
        runtime_library_dirs = (
            [f"@loader_path/libzim/{config.libzim_fname}"]
            if sysplatform == "Darwin"
            else ["$ORIGIN/libzim/"]
        )

    wrapper_extension = Extension(
        name="libzim",
        sources=["libzim/libzim.pyx", "libzim/libwrapper.cpp"],
        include_dirs=include_dirs,
        libraries=["zim"],
        library_dirs=library_dirs,
        runtime_library_dirs=runtime_library_dirs,
        extra_compile_args=["-std=c++11", "-Wall", "-Wextra"],
        language="c++",
        define_macros=define_macros,
    )
    return cythonize([wrapper_extension], compiler_directives=compiler_directives)


class LibzimBuildExt(build_ext):
    def finalize_options(self):
        """Workaround for rpath bug in distutils for macOS"""
        super().finalize_options()

        if config.platform == "Darwin":
            # Special treatment of rpath in case of OSX, to work around python
            # distutils bug 36353. This constructs proper rpath arguments for clang.
            # See https://bugs.python.org/issue36353
            for path in self.rpath:
                for ext in self.extensions:
                    ext.extra_link_args.append("-Wl,-rpath," + path)
            self.rpath[:] = []

    def build_extension(self, ext):
        """Properly set rpath on macOS and optionaly trigger macOS signing"""
        super().build_extension(ext)

        if config.platform == "Darwin" and not config.use_system_libzim:
            # use install_name_tool to properly set the rpath on the wrapper
            # so it finds libzim in a subfolder
            # for ext in self.extensions:
            fpath = self.get_ext_fullpath(ext.name)

            subprocess.run(
                [
                    "/usr/bin/env",
                    "install_name_tool",
                    "-change",
                    config.libzim_fname,
                    f"@loader_path/libzim/{config.libzim_fname}",
                    str(fpath),
                ],
                check=True,
            )

        if config.platform == "Darwin" and config.should_sign_apple:
            self.sign_extension_macos(ext)

    def sign_extension_macos(self, ext):
        """sign and notarize extension on macOS"""
        print("Signing & Notarization of the extension")

        if not config.can_sign_apple:
            raise EnvironmentError("Can't sign for apple. Missing information")

        ext_fpath = pathlib.Path(self.get_ext_fullpath(ext.name))

        print("> signing the extension")
        subprocess.run(
            [
                "/usr/bin/env",
                "codesign",
                "--force",
                "--sign",
                config.apple_signing_identity,
                str(ext_fpath),
                "--deep",
                "--timestamp",
            ],
            check=True,
        )

        print("> create ZIP package for notarization request")
        ext_zip = ext_fpath.with_name(f"{ext_fpath.name}.zip")
        subprocess.run(
            [
                "/usr/bin/env",
                "ditto",
                "-c",
                "-k",
                "--keepParent",
                str(ext_fpath),
                str(ext_zip),
            ]
        )

        print("> request notarization")
        # security unlock-keychain -p mysecretpassword $(pwd)/build.keychain
        subprocess.run(
            [
                "/usr/bin/env",
                "xcrun",
                "notarytool",
                "submit",
                "--keychain",
                config.apple_signing_keychain,
                "--keychain-profile",
                config.apple_signing_keychain_profile,
                "--wait",
                ext_zip,
            ],
            check=True,
        )

        print("> removing zip file")
        ext_zip.unlink()

        print("> displaying request status (should be rejected)")
        subprocess.run(
            [
                "/usr/bin/env",
                "spctl",
                "--assess",
                "-vv",
                "--type",
                "install",
                str(ext_fpath),
            ],
            check=False,
        )


class DownloadLibzim(Command):
    """dedicated command to solely download libzim binary"""

    user_options = []

    def initialize_options(self):
        ...

    def finalize_options(self):
        ...

    def run(self):
        config.download_to_dest()


class LibzimClean(Command):
    user_options = []

    def initialize_options(self):
        ...

    def finalize_options(self):
        ...

    def run(self):
        config.cleanup()


if len(sys.argv) == 2 and sys.argv[1] in config.buildless_commands:
    ext_modules = None
else:
    ext_modules = get_cython_extension()

setup(
    cmdclass={
        "build_ext": LibzimBuildExt,
        "download_libzim": DownloadLibzim,
        "clean": LibzimClean,
    },
    ext_modules=ext_modules,
)
