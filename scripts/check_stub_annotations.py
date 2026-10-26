"""Check that type stubs annotations match the compiled module ones

Cython keeps the annotations of the `.pyx` source on the compiled functions
(as strings, in `__annotations__`). This script compares them with the ones
declared in the `libzim/*.pyi` stubs, for every public object of every libzim
submodule, and reports mismatches.

It complements `mypy.stubtest`, which checks names, parameters and defaults
but not annotation types.

Annotations missing on either side are not reported: only conflicting ones.
"""

import ast
import importlib
import inspect
import sys
from collections.abc import Callable, Iterator
from pathlib import Path
from types import ModuleType
from typing import Any

import libzim

STUBS_DIR = Path(__file__).resolve().parent.parent / "libzim"

# runtime names which are aliases of a stub name ; completed at runtime with
# objects exported under another name, like `("Blob", WritingBlob)`
ALIASES = {
    "pybool": "bool",  # `pybool = type(True)` in libzim.pyx
    "pyint": "int",  # `pyint = type(1)` in libzim.pyx
}


class Normalizer(ast.NodeTransformer):
    """Normalize an annotation AST so that equivalent spellings compare equal"""

    def __init__(self, self_type: str | None):
        self.self_type = self_type

    def visit_Constant(self, node: ast.Constant) -> ast.AST:
        # forward reference: "Archive" -> Archive
        if isinstance(node.value, str):
            return self.visit(ast.parse(node.value, mode="eval").body)
        return node

    def visit_Attribute(self, node: ast.Attribute) -> ast.AST:
        # pathlib.Path -> Path ; typing.Self -> Self
        return self.visit_Name(ast.Name(id=node.attr, ctx=ast.Load()))

    def visit_Subscript(self, node: ast.Subscript) -> ast.AST:
        node = self.generic_visit(node)  # pyright: ignore[reportAssignmentType]
        # Generator[X, None, None] -> Generator[X] (default type parameters)
        if (
            isinstance(node.value, ast.Name)
            and node.value.id == "Generator"
            and isinstance(node.slice, ast.Tuple)
        ):
            elts = list(node.slice.elts)
            while len(elts) > 1 and ast.unparse(elts[-1]) == "None":
                elts.pop()
            node.slice = elts[0] if len(elts) == 1 else ast.Tuple(elts, ast.Load())
        return node

    def visit_Name(self, node: ast.Name) -> ast.AST:
        name = ALIASES.get(node.id, node.id)
        if name == "Self" and self.self_type:
            name = self.self_type
        return ast.Name(id=name, ctx=ast.Load())


def normalize(annotation: str | ast.expr, self_type: str | None) -> str:
    """Normalized textual representation of an annotation"""
    if isinstance(annotation, str):
        annotation = ast.parse(annotation, mode="eval").body
    return ast.unparse(Normalizer(self_type).visit(annotation))


def stub_annotations(func: ast.FunctionDef) -> dict[str, ast.expr]:
    """Annotations of a stub function, keyed like `__annotations__`"""
    args = func.args
    annotations: dict[str, ast.expr] = {}
    for arg in [*args.posonlyargs, *args.args, *args.kwonlyargs]:
        if arg.annotation is not None:
            annotations[arg.arg] = arg.annotation
    for arg in (args.vararg, args.kwarg):
        if arg is not None and arg.annotation is not None:
            annotations[arg.arg] = arg.annotation
    if func.returns is not None:
        annotations["return"] = func.returns
    return annotations


def runtime_callable(obj: Any, func: ast.FunctionDef) -> Callable[..., Any] | None:
    """The runtime callable matching a stub function definition, if any"""
    decorators = {
        d.id if isinstance(d, ast.Name) else ast.unparse(d) for d in func.decorator_list
    }
    if "property" in decorators:
        # Cython properties are getset descriptors, without annotations
        fget = getattr(obj, "fget", None)
        return fget if callable(fget) else None
    if any(d.endswith((".setter", ".deleter")) for d in decorators):
        return None
    return obj if callable(obj) else None


def compare(
    qualname: str,
    func: ast.FunctionDef,
    runtime: Callable[..., Any],
    self_type: str | None,
) -> Iterator[str]:
    """Mismatches between a stub function and its runtime counterpart"""
    try:
        runtime_annotations: dict[str, Any] = inspect.get_annotations(runtime)
    except TypeError:
        return
    for name, stub_annotation in stub_annotations(func).items():
        runtime_annotation = runtime_annotations.get(name)
        if not isinstance(runtime_annotation, str):
            continue
        stub_value = normalize(stub_annotation, self_type)
        runtime_value = normalize(runtime_annotation, self_type)
        if stub_value != runtime_value:
            where = "return" if name == "return" else f"parameter {name!r}"
            yield (
                f"{qualname} {where}: stub has `{stub_value}`, "
                f"runtime has `{runtime_value}`"
            )


def check_module(module: ModuleType) -> Iterator[str]:
    stub_path = STUBS_DIR / f"{module.__name__.rsplit('.', 1)[-1]}.pyi"
    stub = ast.parse(stub_path.read_text(), filename=str(stub_path))
    for node in stub.body:
        if not isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            continue
        runtime = getattr(module, node.name, None)
        if node.name.startswith("_") or runtime is None:
            continue  # missing objects are reported by stubtest
        qualname = f"{module.__name__}.{node.name}"
        if isinstance(node, ast.FunctionDef):
            yield from compare(qualname, node, runtime, None)
        elif isinstance(node, ast.ClassDef):
            for member in node.body:
                if not isinstance(member, ast.FunctionDef):
                    continue
                try:
                    runtime_member = inspect.getattr_static(runtime, member.name)
                except AttributeError:
                    continue  # reported by stubtest
                if isinstance(runtime_member, (staticmethod, classmethod)):
                    runtime_member = runtime_member.__func__
                func = runtime_callable(runtime_member, member)
                if func is not None:
                    yield from compare(
                        f"{qualname}.{member.name}", member, func, node.name
                    )


def main() -> int:
    modules = [
        importlib.import_module(f"libzim.{name}")
        for name in libzim.__all__  # pyright: ignore[reportAttributeAccessIssue]
    ]
    for module in modules:
        for name in module.__all__:
            runtime_name = getattr(getattr(module, name), "__name__", name)
            if runtime_name != name:
                ALIASES[runtime_name] = name

    errors: list[str] = []
    for module in modules:
        errors.extend(check_module(module))
    for error in errors:
        print(f"error: {error}")  # noqa: T201
    print(  # noqa: T201
        f"Found {len(errors)} annotation mismatch(es) between stubs and runtime"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
