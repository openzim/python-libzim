"""
Script called by mkdocs-gen-files that generates markdown documents
with API reference placeholders.

https://oprypin.github.io/mkdocs-gen-files/api.html
"""

from pathlib import Path

import mkdocs_gen_files

nav = mkdocs_gen_files.Nav()

root = Path(__file__).parent.parent.parent
src = root / "libzim"
api_reference = Path("api_reference")

for path in sorted(src.rglob("*.pyi")):
    module_path = path.relative_to(root).with_suffix("")

    # Package docs get the parent module name.
    if module_path.name == "__init__":
        module_path = module_path.parent
    elif module_path.name.startswith("_"):
        # Skip other hidden items
        continue
    identifier = ".".join(module_path.parts)

    doc_path = identifier + ".md"
    full_doc_path = api_reference / doc_path
    print(f"{full_doc_path=}")

    nav[identifier] = doc_path

    # Create a document with mkdocstrings placeholders.
    with mkdocs_gen_files.open(full_doc_path, "w") as fd:
        fd.write(f"""---
title: {identifier}
---

::: {identifier}
""")

    # Make the edit button on the page link to the source file.
    mkdocs_gen_files.set_edit_path(full_doc_path, Path("..") / path.relative_to(root))

# Write a navigation file that will be interpreted by literate-nav.
with mkdocs_gen_files.open(api_reference / "NAVIGATION.md", "w") as fd:
    fd.writelines(nav.build_literate_nav())
