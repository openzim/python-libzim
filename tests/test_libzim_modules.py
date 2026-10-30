import importlib
import sys

import pytest

import libzim


@pytest.mark.parametrize("module_name", libzim.__all__)
def test_submodule_exports(module_name: str):
    module = importlib.import_module(f"libzim.{module_name}")
    assert sys.modules[f"libzim.{module_name}"] is module
    for name in module.__all__:
        assert getattr(module, name) is not None


@pytest.mark.parametrize("module_name", libzim.__all__)
def test_submodule_reimport_uses_loader(monkeypatch, module_name: str):
    monkeypatch.delitem(sys.modules, f"libzim.{module_name}", raising=False)
    module = importlib.import_module(f"libzim.{module_name}")
    assert module is importlib.import_module(f"libzim.{module_name}")


def test_submodules_not_registered_under_member_names():
    for module_name in libzim.__all__:
        module = importlib.import_module(f"libzim.{module_name}")
        for name in module.__all__:
            assert sys.modules.get(name) is not module


def test_unknown_submodule_import_fails():
    with pytest.raises(ImportError, match=r"libzim\.unknown"):
        importlib.import_module("libzim.unknown")
