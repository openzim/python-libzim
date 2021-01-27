#!/usr/bin/env python

import os
import gc
import uuid
from urllib.request import urlretrieve

import pytest

import libzim.writer
from libzim.reader import Archive


# expected data for tests ZIMs (see `all_zims`)
ZIMS_DATA = {
    "blank.zim": {
        "filename": "blank.zim",
        "filesize": 25675,
        "new_ns": True,
        "mutlipart": False,
        "zim_uuid": None,
        "metadata_keys": [],
        "test_metadata": None,
        "test_metadata_value": None,
        "has_main_entry": False,
        "has_favicon_entry": False,
        "has_fulltext_index": False,
        "has_title_index": True,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 0,
        "suggestion_string": "",
        "suggestion_count": 0,
        "suggestion_result": [],
        "search_string": "",
        "search_count": 0,
        "search_result": [],
        "test_path": None,
        "test_title": None,
        "test_mimetype": None,
        "test_size": None,
        "test_content_includes": None,
        "test_redirect": None,
        "test_redirect_to": None,
    },
    "zimfile.zim": {
        "filename": "zimfile.zim",
        "filesize": 569304,
        "new_ns": False,
        "mutlipart": False,
        "zim_uuid": "6f1d19d0633f087bfb557ac324ff9baf",
        "metadata_keys": [
            "Counter",
            "Creator",
            "Date",
            "Description",
            "Flavour",
            "Language",
            "Name",
            "Publisher",
            "Scraper",
            "Tags",
            "Title",
        ],
        "test_metadata": "Name",
        "test_metadata_value": "wikipedia_en_ray_charles",
        "has_main_entry": True,
        "has_favicon_entry": True,
        "has_fulltext_index": True,
        "has_title_index": True,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 371,
        "suggestion_string": "lucky",
        "suggestion_count": 2,  # includes redirect?
        "suggestion_result": ["A/That_Lucky_Old_Sun"],
        "search_string": "lucky",
        "search_count": 1,
        "search_result": ["A/That_Lucky_Old_Sun"],
        "test_path": "A/A_Song_for_You",
        "test_title": "A Song for You",
        "test_mimetype": "text/html",
        "test_size": 7461,
        "test_content_includes": "which was released in 1970 on Shelter Records",
        "test_redirect": "A/What_I_Say",
        "test_redirect_to": "A/What'd_I_Say",
    },
    "example.zim": {
        "filename": "example.zim",
        "filesize": 128326,
        "new_ns": False,
        "mutlipart": False,
        "zim_uuid": "b0fbc99668acfdadc1e75db00d7010e6",
        "metadata_keys": [
            "Counter",
            "Creator",
            "Date",
            "Description",
            "Language",
            "Name",
            "Publisher",
            "Title",
        ],
        "test_metadata": "Name",
        "test_metadata_value": "kiwix.wikibooks_ay_all",
        "has_main_entry": True,
        "has_favicon_entry": True,
        "has_fulltext_index": True,
        "has_title_index": False,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 54,
        "suggestion_string": "Nayriri",
        "suggestion_count": 2,
        "suggestion_result": ["A/index", "A/Nayriri_Uñstawi"],
        "search_string": "Nayriri",
        "search_count": 1,
        "search_result": ["A/Nayriri_Uñstawi"],
        "test_path": "A/Nayriri_Uñstawi",
        "test_title": "Nayriri Uñstawi",
        "test_mimetype": "text/html",
        "test_size": 2652,
        "test_content_includes": "This article is issued from",
        "test_redirect": "A/Main_Page",
        "test_redirect_to": "A/Nayriri_Uñstawi",
    },
    "corner_cases.zim": {
        "filename": "corner_cases.zim",
        "filesize": 75741,
        "new_ns": False,
        "mutlipart": False,
        "zim_uuid": "9150439f963dff9ec91ca09a41962d71",
        "metadata_keys": [
            "Counter",
            "Creator",
            "Date",
            "Description",
            "Flavour",
            "Language",
            "Name",
            "Publisher",
            "Scraper",
            "Source",
            "Tags",
            "Title",
        ],
        "test_metadata": "Title",
        "test_metadata_value": "=ZIM corner cases",
        "has_main_entry": True,
        "has_favicon_entry": True,
        "has_fulltext_index": True,
        "has_title_index": True,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 19,
        "suggestion_string": "empty",
        "suggestion_count": 1,
        "suggestion_result": ["A/empty.html"],
        "search_string": "empty",
        "search_count": 1,
        "search_result": ["A/empty.html"],
        "test_path": "A/empty.html",
        "test_title": "empty",
        "test_mimetype": "text/html",
        "test_size": 0,
        "test_content_includes": "",
        "test_redirect": "-/favicon",
        "test_redirect_to": "I/empty.png",
    },
}


def get_pytest_param(name, *fields):
    args = [ZIMS_DATA[name].get(field, f"MISSING-VALUE {field}") for field in fields]
    return pytest.param(*args)


def get_pytest_params_list(*fields):
    return [get_pytest_param(name, *fields) for name in ZIMS_DATA.keys()]


def parametrize_for(fields):
    return (
        ", ".join(fields),
        get_pytest_params_list(*fields),
    )


@pytest.fixture(scope="module")
def all_zims(tmpdir_factory):
    """creates a temp dir with all ZIM files inside:

    - downloaded ones from libzim
    - blank one created with pylibzim"""
    temp_dir = tmpdir_factory.mktemp("data")

    libzim_urls = [
        f"https://github.com/kiwix/kiwix-lib/raw/master/test/data/{name}"
        for name in ("zimfile.zim", "example.zim", "corner_cases.zim")
    ]

    # download libzim tests
    for url in libzim_urls:
        urlretrieve(url, temp_dir / os.path.basename(url))  # nosec

    # create blank using pylibzim
    creator = libzim.writer.Creator(temp_dir / "blank.zim")
    with creator:
        pass

    return temp_dir


def test_open_badfile(tmpdir):
    fpath = tmpdir / "not-exist.zim"
    with pytest.raises(RuntimeError):
        Archive(fpath)

    fpath = tmpdir / "not-zim.zim"
    with open(fpath, "w") as fh:
        fh.write("text file")
    with pytest.raises(RuntimeError):
        Archive(fpath)


def test_content_ref_keep(all_zims):
    """Get the memoryview on a content and loose the reference on the article.
    We try to load a lot of other articles to detect possible use of dandling pointer
    """
    archive = Archive(all_zims / "zimfile.zim")
    content = None

    def get_content():
        nonlocal content
        entry = archive.get_entry_by_path("A/That_Lucky_Old_Sun")
        item = entry.get_item()
        assert isinstance(item.content, memoryview)
        content = item.content

    get_content()  # Now we have a content but no reference to the entry/item.
    gc.collect()
    # Load a lot of content
    for i in range(0, archive.entry_count, 2):
        entry = archive._get_entry_by_id(i)
        if not entry.is_redirect:
            _ = entry.get_item().content
    # Check everything is ok
    assert len(content) == 3559
    assert (
        bytes(content[:100]) == b'<!DOCTYPE html>\n<html class="client-js"><head>\n  '
        b'<meta charset="UTF-8">\n  <title>That Lucky Old Sun<'  # noqa
    )


@pytest.mark.parametrize(
    *parametrize_for(["filename", "filesize", "new_ns", "mutlipart", "zim_uuid"])
)
def test_reader_archive(all_zims, filename, filesize, new_ns, mutlipart, zim_uuid):
    fpath = all_zims / filename
    zim = Archive(fpath)

    # check externaly verifiable data
    assert zim.filename == fpath
    assert zim.filesize == os.path.getsize(fpath)
    if filesize is not None:
        assert zim.filesize == filesize
    assert zim.has_new_namespace_scheme is new_ns
    assert zim.is_multipart is mutlipart
    assert str(fpath) in str(zim)

    # ensure uuid is returned
    assert isinstance(zim.uuid, uuid.UUID)
    assert len(zim.uuid.hex) == 32
    if zim_uuid:
        assert zim.uuid.hex == zim_uuid


@pytest.mark.parametrize(
    *parametrize_for(
        ["filename", "metadata_keys", "test_metadata", "test_metadata_value"]
    )
)
def test_reader_metadata(
    all_zims, filename, metadata_keys, test_metadata, test_metadata_value
):

    zim = Archive(all_zims / filename)

    # make sure metadata_keys is empty
    assert zim.metadata_keys == metadata_keys
    if test_metadata:
        assert zim.get_metadata(test_metadata).decode("UTF-8") == test_metadata_value


@pytest.mark.parametrize(
    *parametrize_for(["filename", "new_ns", "has_main_entry", "has_favicon_entry"])
)
def test_reader_main_favicon_entries(
    all_zims, filename, new_ns, has_main_entry, has_favicon_entry
):
    zim = Archive(all_zims / filename)

    # make sure we have no main entry
    assert zim.has_main_entry is has_main_entry
    if has_main_entry is False:
        with pytest.raises(RuntimeError):
            assert zim.main_entry
    else:
        assert zim.main_entry
        if new_ns:
            assert zim.main_entry.path == "mainPath"

    # make sure we have no favicon entry
    assert zim.has_favicon_entry is has_favicon_entry
    if has_favicon_entry is False:
        with pytest.raises(RuntimeError):
            assert zim.favicon_entry
    else:
        assert zim.favicon_entry
        if new_ns:
            assert zim.favicon_entry.path == "-/favicon"


@pytest.mark.parametrize(
    *parametrize_for(["filename", "has_fulltext_index", "has_title_index"])
)
def test_reader_has_index(all_zims, filename, has_fulltext_index, has_title_index):
    zim = Archive(all_zims / filename)

    # we should not get a fulltext index but title should
    assert zim.has_fulltext_index is has_fulltext_index
    assert zim.has_title_index is has_title_index


@pytest.mark.parametrize(*parametrize_for(["filename", "has_checksum", "is_valid"]))
def test_reader_checksum(all_zims, filename, has_checksum, is_valid):
    zim = Archive(all_zims / filename)

    # verify checksum
    assert zim.has_checksum is has_checksum
    assert isinstance(zim.checksum, str)
    assert len(zim.checksum) == 32 if has_checksum else 0
    assert zim.checksum != zim.uuid
    assert zim.check() is is_valid


@pytest.mark.parametrize(
    *parametrize_for(
        [
            "filename",
            "entry_count",
            "suggestion_string",
            "suggestion_count",
            "suggestion_result",
            "search_string",
            "search_count",
            "search_result",
        ]
    )
)
def test_reader_suggest_search(
    all_zims,
    filename,
    entry_count,
    suggestion_string,
    suggestion_count,
    suggestion_result,
    search_string,
    search_count,
    search_result,
):
    zim = Archive(all_zims / filename)

    # suggestion and search results
    assert zim.entry_count == entry_count
    assert (
        zim.get_estimated_suggestions_results_count(suggestion_string)
        == suggestion_count
    )
    assert list(zim.suggest(suggestion_string)) == suggestion_result
    assert zim.get_estimated_search_results_count(search_string) == search_count
    assert list(zim.search(search_string)) == search_result


@pytest.mark.parametrize(
    *parametrize_for(
        [
            "filename",
            "test_path",
            "test_title",
            "test_mimetype",
            "test_size",
            "test_content_includes",
        ]
    )
)
def test_reader_get_entries(
    all_zims,
    filename,
    test_path,
    test_title,
    test_mimetype,
    test_size,
    test_content_includes,
):
    zim = Archive(all_zims / filename)

    # entries
    with pytest.raises(KeyError):
        zim.get_entry_by_path("___missing")

    if test_path:
        assert zim.has_entry_by_path(test_path)
        entry = zim.get_entry_by_path(test_path)
        assert entry.title == test_title
        assert entry.path == test_path
        assert test_path in str(entry)
        assert test_title in str(entry)

        item = entry.get_item()
        assert item.title == test_title
        assert item.path == test_path
        assert test_path in str(item)
        assert test_title in str(item)
        assert item.mimetype == test_mimetype
        assert item.size == test_size
        assert isinstance(item.content, memoryview)
        assert test_content_includes in bytes(item.content).decode("UTF-8")

    with pytest.raises(KeyError):
        zim.get_entry_by_title("___missing")

    if test_title:
        assert zim.has_entry_by_title(test_title)
        assert zim.get_entry_by_title(test_title).path == entry.path


@pytest.mark.parametrize(
    *parametrize_for(["filename", "test_redirect", "test_redirect_to"])
)
def test_reader_redirect(all_zims, filename, test_redirect, test_redirect_to):
    zim = Archive(all_zims / filename)

    if test_redirect:
        assert zim.get_entry_by_path(test_redirect).is_redirect

        if test_redirect_to:
            target_entry = zim.get_entry_by_path(test_redirect)
            assert target_entry.get_redirect_entry().path == test_redirect_to
            # make sure get_item resolves it
            assert target_entry.get_item().path == test_redirect_to
            # should be last redirect
            assert target_entry.get_redirect_entry().is_redirect is False
            with pytest.raises(RuntimeError):
                target_entry.get_redirect_entry().get_redirect_entry()


@pytest.mark.parametrize(*parametrize_for(["filename"]))
def test_reader_by_id(all_zims, filename):
    zim = Archive(all_zims / filename)

    # test index access
    for index in range(0, zim.entry_count - 1):
        assert zim._get_entry_by_id(index)._index == index
        assert zim._get_entry_by_id(index).get_item()._index >= 0
