import re
import sys

from libzim.version import get_libzim_version, get_versions, print_versions


def test_version_print_version_with_stdout(capsys):
    print_versions()
    print("", file=sys.stdout, flush=True)
    stdout, stderr = capsys.readouterr()
    assert len(stdout) != 0


def test_version_print_version_with_stderr(capsys):
    print_versions(sys.stderr)
    print("", file=sys.stderr, flush=True)
    stdout, stderr = capsys.readouterr()
    assert len(stderr) != 0


def test_get_versions():
    versions = get_versions()
    assert versions
    assert "libzim" in versions
    assert len(versions.keys()) > 1
    for library, version in versions.items():
        assert isinstance(library, str)
        assert isinstance(version, str)


def test_get_libzim_version():
    # libzim uses semantic versioning
    assert re.match(r"\d+\.\d+\.\d+", get_libzim_version())
