import sys

from libzim.version import Version


def test_get_verions():
    versions = Version.get_versions()
    assert len(versions) != 0


def test_print_verion_with_stdout(capfd):
    Version.print_version()
    stdout, stderr = capfd.readouterr()
    assert len(stdout) != 0


def test_print_verion_with_stderr(capfd):
    Version.print_version(sys.stderr)
    stdout, stderr = capfd.readouterr()
    assert len(stderr) != 0
