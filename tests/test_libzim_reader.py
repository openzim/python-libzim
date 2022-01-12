#!/usr/bin/env python

import gc
import os
import pathlib
import uuid
from urllib.request import urlretrieve

import pytest

import libzim.writer
from libzim.reader import Archive
from libzim.search import Query, Searcher
from libzim.suggestion import SuggestionSearcher

# expected data for tests ZIMs (see `all_zims`)
ZIMS_DATA = {
    "blank.zim": {
        "filename": "blank.zim",
        "filesize": 1173,
        "new_ns": True,
        "mutlipart": False,
        "zim_uuid": None,
        "metadata_keys": ["Counter"],
        "test_metadata": None,
        "test_metadata_value": None,
        "has_main_entry": False,
        "has_favicon_entry": False,
        "has_fulltext_index": False,
        "has_title_index": False,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 0,
        "all_entry_count": 2,
        "article_count": 0,
        "suggestion_string": None,
        "suggestion_count": 0,
        "suggestion_result": [],
        "search_string": None,
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
        "all_entry_count": 371,
        "article_count": 284,
        "suggestion_string": "lucky",
        "suggestion_count": 1,
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
        "filesize": 259145,
        "new_ns": True,
        "mutlipart": False,
        "zim_uuid": "5dc0b3af5df20925f0cad2bf75e78af6",
        "metadata_keys": [
            "Counter",
            "Creator",
            "Date",
            "Description",
            "Language",
            "Publisher",
            "Scraper",
            "Tags",
            "Title",
        ],
        "test_metadata": "Title",
        "test_metadata_value": "Wikibooks",
        "has_main_entry": True,
        "has_favicon_entry": False,
        "has_fulltext_index": True,
        "has_title_index": True,
        "has_checksum": True,
        "checksum": "abcd818c87079cb29282282b47ee46ec",
        "is_valid": True,
        "entry_count": 60,
        "all_entry_count": 75,
        "article_count": 0,
        "suggestion_string": "Free",
        "suggestion_count": 1,
        "suggestion_result": [
            "FreedomBox for Communities_Offline Wikipedia "
            + "- Wikibooks, open books for an open world.html"
        ],
        "search_string": "main",
        "search_count": 2,
        "search_result": [
            "Wikibooks.html",
            "FreedomBox for Communities_Offline Wikipedia "
            + "- Wikibooks, open books for an open world.html",
        ],
        "test_path": "FreedomBox for Communities_Offline Wikipedia - Wikibooks, "
        "open books for an open world.html",
        "test_title": "FreedomBox for Communities/Offline Wikipedia - Wikibooks, "
        "open books for an open world",
        "test_mimetype": "text/html",
        "test_size": 52771,
        "test_content_includes": "looking forward to your contributions.",
        "test_redirect": None,
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
        "all_entry_count": 19,
        "article_count": 1,
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
    "small.zim": {
        "filename": "small.zim",
        "filesize": 41155,
        "new_ns": True,
        "mutlipart": False,
        "zim_uuid": "3581ae7eedd57e6cd2f1c0cab073643f",
        "metadata_keys": [
            "Counter",
            "Creator",
            "Date",
            "Description",
            "Illustration_48x48@1",
            "Language",
            "Publisher",
            "Scraper",
            "Tags",
            "Title",
        ],
        "test_metadata": "Title",
        "test_metadata_value": "Test ZIM file",
        "has_main_entry": True,
        "has_favicon_entry": True,
        "has_fulltext_index": False,
        "has_title_index": True,
        "has_checksum": True,
        "checksum": None,
        "is_valid": True,
        "entry_count": 2,
        "all_entry_count": 16,
        "article_count": 1,
        "suggestion_string": None,
        "suggestion_count": None,
        "suggestion_result": None,
        "search_string": None,
        "search_count": None,
        "search_result": None,
        "test_path": "main.html",
        "test_title": "Test ZIM file",
        "test_mimetype": "text/html",
        "test_size": 207,
        "test_content_includes": "Test ZIM file",
        "test_redirect": None,
        "test_redirect_to": None,
    },
}

skip_if_offline = pytest.mark.skipif(
    bool(os.getenv("OFFLINE")), reason="OFFLINE environ requested offline-only"
)


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
    ] + ["https://github.com/openzim/zim-testing-suite/raw/main/data/nons/small.zim"]

    # download libzim tests
    for url in libzim_urls:
        urlretrieve(url, temp_dir / os.path.basename(url))  # nosec

    # create blank using pylibzim
    creator = libzim.writer.Creator(temp_dir / "blank.zim")
    with creator:
        pass

    return pathlib.Path(temp_dir)


def test_open_badfile(tmpdir):
    fpath = tmpdir / "not-exist.zim"
    with pytest.raises(RuntimeError):
        Archive(fpath)

    fpath = tmpdir / "not-zim.zim"
    with open(fpath, "w") as fh:
        fh.write("text file")
    with pytest.raises(RuntimeError):
        Archive(fpath)


@skip_if_offline
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


@skip_if_offline
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


@skip_if_offline
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
        item = zim.get_metadata_item(test_metadata)
        assert item.mimetype == "text/plain"
        assert item.size > 1


@skip_if_offline
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
            assert zim.main_entry.path == "mainPage"

    # make sure we have no favicon entry
    assert zim.has_illustration(48) is has_favicon_entry
    if has_favicon_entry:
        assert 48 in zim.get_illustration_sizes()

    if has_favicon_entry is False:
        with pytest.raises(KeyError):
            assert zim.get_illustration_item(48)
    else:
        assert zim.get_illustration_item()
        if new_ns:
            assert zim.get_illustration_item().path == "Illustration_48x48@1"
            assert zim.get_illustration_sizes() == {48}

            assert zim.get_metadata_item("Illustration_48x48@1").mimetype == "image/png"


@skip_if_offline
@pytest.mark.parametrize(
    *parametrize_for(["filename", "has_fulltext_index", "has_title_index"])
)
def test_reader_has_index(all_zims, filename, has_fulltext_index, has_title_index):
    zim = Archive(all_zims / filename)

    # we should not get a fulltext index but title should
    assert zim.has_fulltext_index is has_fulltext_index
    assert zim.has_title_index is has_title_index


@skip_if_offline
@pytest.mark.parametrize(*parametrize_for(["filename", "has_checksum", "is_valid"]))
def test_reader_checksum(all_zims, filename, has_checksum, is_valid):
    zim = Archive(all_zims / filename)

    # verify checksum
    assert zim.has_checksum is has_checksum
    assert isinstance(zim.checksum, str)
    assert len(zim.checksum) == 32 if has_checksum else 0
    assert zim.checksum != zim.uuid
    assert zim.check() is is_valid


@skip_if_offline
@pytest.mark.parametrize(
    *parametrize_for(
        [
            "filename",
            "entry_count",
            "all_entry_count",
            "article_count",
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
    all_entry_count,
    article_count,
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
    assert zim.all_entry_count == all_entry_count
    assert zim.article_count == article_count

    if search_string is not None:
        query = Query().set_query(search_string)
        searcher = Searcher(zim)
        search = searcher.search(query)
        assert search.getEstimatedMatches() == search_count
        assert list(search.getResults(0, search_count)) == search_result

    if suggestion_string is not None:
        suggestion_searcher = SuggestionSearcher(zim)
        suggestion = suggestion_searcher.suggest(suggestion_string)
        assert suggestion.getEstimatedMatches() == suggestion_count
        assert list(suggestion.getResults(0, suggestion_count)) == suggestion_result


@skip_if_offline
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

    # example.zim cannot be queried by title as all its entries have been created
    # with empty titles but the ZIM contains a v1 title listing.
    if test_title and filename != "example.zim":
        assert zim.has_entry_by_title(test_title)
        assert zim.get_entry_by_title(test_title).path == entry.path


@skip_if_offline
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


@skip_if_offline
@pytest.mark.parametrize(*parametrize_for(["filename"]))
def test_reader_by_id(all_zims, filename):
    zim = Archive(all_zims / filename)

    # test index access
    for index in range(0, zim.entry_count - 1):
        assert zim._get_entry_by_id(index)._index == index
        assert zim._get_entry_by_id(index).get_item()._index >= 0


@skip_if_offline
def test_archive_equality(all_zims):
    class Different:
        def __init__(self, filename):
            self.filename = filename

    class Sub(Archive):
        pass

    class Sub2(Archive):
        @property
        def filename(self):
            return 1

    fpath1 = all_zims / "zimfile.zim"
    fpath2 = all_zims / "example.zim"
    zim = Archive(fpath1)

    assert zim != Archive(fpath2)
    assert zim == Archive(fpath1)
    assert zim != Different(fpath1)
    assert zim == Sub(fpath1)
    assert zim != Sub2(fpath1)
