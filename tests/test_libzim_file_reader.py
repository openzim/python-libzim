import gc
from pathlib import Path

import pytest

from libzim.reader import Archive

DATA_DIR = Path(__file__).parent


ZIMFILES = [
    {
        "filename": DATA_DIR / "wikipedia_es_physics_mini.zim",
        "checksum": "99ea7a5598c6040c4f50b8ac0653b703",
        "entry_count": 22027,
        "main_entry": "A/index",
    }
]


@pytest.fixture(params=ZIMFILES)
def zimdata(request):
    return request.param


@pytest.fixture
def reader(zimdata):
    if not zimdata["filename"].exists():
        pytest.skip(f"{zimdata['filename']} doesn't exist")
    return Archive(zimdata["filename"])


@pytest.fixture
def entry_data():
    return {
        "path": "A/Albert_Einstein",
        "title": "Albert Einstein",
        "mimetype": "text/html",
        "entry_id": 663,
        "size": 17343,
    }


def test_zim_filename(reader, zimdata):
    for k, v in zimdata.items():
        if k == "main_entry":
            assert getattr(reader, k).path == v
            continue
        assert getattr(reader, k) == v
    assert isinstance(reader.filename, Path)


def test_zim_read(reader, entry_data):
    entry = reader.get_entry_by_path(entry_data["path"])

    assert entry.path == entry_data["path"]
    assert entry.title == entry_data["title"]
    item = entry.get_item();
    assert item.mimetype == entry_data["mimetype"]
    assert isinstance(item.content, memoryview)
    assert len(item.content) == entry_data["size"]


def test_content_ref_keep(reader):
    """Get the memoryview on a content and loose the reference on the article.
       We try to load a lot of other articles to detect possible use of dandling pointer
    """
    content = None

    def get_content():
        nonlocal content
        entry = reader.get_entry_by_path("A/Albert_Einstein")
        item = entry.get_item()
        assert isinstance(item.content, memoryview)
        content = item.content

    get_content()  # Now we have a content but no reference to the entry/item.
    gc.collect()
    # Load a lot of content
    for i in range(0, reader.entry_count, 2):
        entry = reader.get_entry_by_id(i)
        if not entry.is_redirect:
            _ = entry.get_item().content
    # Check everything is ok
    assert len(content) == 17343
    assert (
        bytes(content[:100])
        == b'<!DOCTYPE html>\n<html class="client-js"><head>\n  <meta charset="UTF-8">\n  <title>Albert Einstein</ti'  # noqa
    )


def test_get_entry_by_id(reader, entry_data):
    entry = reader.get_entry_by_id(entry_data["entry_id"])

    assert entry.path == entry_data["path"]
    assert entry.title == entry_data["title"]
    item = entry.get_item();
    assert item.mimetype == entry_data["mimetype"]
    assert isinstance(item.content, memoryview)
    assert len(item.content) == entry_data["size"]


def test_suggest(reader):
    results = reader.suggest("Einstein")
    assert "A/Albert_Einstein" in list(results)


def test_search(reader):
    results = reader.search("Einstein")
    assert len(list(results)) == 10


def test_get_wrong_entry(reader):
    with pytest.raises(IndexError):  # out of range
        reader.get_entry_by_id(reader.entry_count + 100)
    with pytest.raises(KeyError):
        reader.get_entry_by_path("A/I_do_not_exists")


def test_redirects(reader):
    # we can access target entry from a redirect one
    abundante = reader.get_entry_by_path("A/Abundante")
    assert abundante.is_redirect
    target = abundante.get_redirect_entry()
    assert target.path != abundante.path

    # we can't access a target on non-redirect entry
    assert target.is_redirect is False
    with pytest.raises(RuntimeError):
        target.get_redirect_entry()
