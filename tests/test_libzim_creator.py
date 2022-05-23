#!/usr/bin/env python

import base64
import datetime
import itertools
import pathlib
import subprocess
import sys
from typing import Dict

import pytest

import libzim.writer
from libzim.reader import Archive
from libzim.search import Query, Searcher
from libzim.suggestion import SuggestionSearcher
from libzim.writer import (
    Blob,
    ContentProvider,
    Creator,
    FileProvider,
    Hint,
    Item,
    StringProvider,
)

HOME_PATH = "lorem_ipsum"


class StaticItem(libzim.writer.Item):
    def __init__(self, **kwargs):
        super().__init__()
        for k, v in kwargs.items():
            setattr(self, k, v)

    def get_path(self) -> str:
        return getattr(self, "path", "")

    def get_title(self) -> str:
        return getattr(self, "title", "")

    def get_mimetype(self) -> str:
        return getattr(self, "mimetype", "")

    def get_contentprovider(self) -> libzim.writer.ContentProvider:
        if getattr(self, "filepath", None):
            return FileProvider(filepath=self.filepath)
        return StringProvider(content=getattr(self, "content", ""))

    def get_hints(self) -> Dict[Hint, int]:
        return getattr(self, "hints", {Hint.FRONT_ARTICLE: True})


@pytest.fixture(scope="function")
def fpath(tmpdir):
    return pathlib.Path(tmpdir / "test.zim")


@pytest.fixture(scope="module")
def favicon_data():
    return base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQ"
        + "ImWO4ISn6HwAE2QIGKsd69QAAAABJRU5ErkJggg=="
    )


@pytest.fixture(scope="module")
def lipsum():
    return (
        "<html><head><title>Lorem Ipsum</title></head><body>"
        "<h2>What is Lorem Ipsum?</h2> <p><strong>Lorem Ipsum</strong> is"
        "simply dummy text of the printing and typesetting industry. Lorem"
        "Ipsum has been the industry's standard dummy text ever since the"
        "1500s, when an unknown printer took a galley of type and scrambled it"
        "to make a type specimen book. It has survived not only five centuries,"
        "but also the leap into electronic typesetting, remaining essentially"
        "unchanged. It was popularised in the 1960s with the release of"
        "Letraset sheets containing Lorem Ipsum passages, and more recently"
        "with desktop publishing software like Aldus PageMaker including"
        "versions of Lorem Ipsum.</p> </div><div> <h2>Why do we use it?</h2>"
        "<p>It is a long established fact that a reader will be distracted by"
        "the readable content of a page when looking at its layout. The point"
        "of using Lorem Ipsum is that it has a more-or-less normal distribution"
        "of letters, as opposed to using 'Content here, content here', making"
        "it look like readable English. Many desktop publishing packages and"
        "web page editors now use Lorem Ipsum as their default model text, and"
        "a search for 'lorem ipsum' will uncover many web sites still in their"
        "infancy. Various versions have evolved over the years, sometimes by"
        "accident, sometimes on purpose (injected humour and the like).</p>"
        "</div><br><div> <h2>Where does it come from?</h2> <p>Contrary to"
        "popular belief, Lorem Ipsum is not simply random text. It has roots in"
        "a piece of classical Latin literature from 45 BC, making it over 2000"
        "years old. Richard McClintock, a Latin professor at Hampden-Sydney"
        "College in Virginia, looked up one of the more obscure Latin words,"
        "consectetur, from a Lorem Ipsum passage, and going through the cites"
        "of the word in classical literature, discovered the undoubtable"
        'source. Lorem Ipsum comes from sections 1.10.32 and 1.10.33 of "de'
        'Finibus Bonorum et Malorum" (The Extremes of Good and Evil) by Cicero,'
        "written in 45 BC. This book is a treatise on the theory of ethics,"
        "very popular during the Renaissance. The first line of Lorem Ipsum,"
        '"Lorem ipsum dolor sit amet..", comes from a line in section'
        "1.10.32.</p><p>The standard chunk of Lorem Ipsum used since the 1500s"
        "is reproduced below for those interested. Sections 1.10.32 and 1.10.33"
        'from "de Finibus Bonorum et Malorum" by Cicero are also reproduced in'
        "their exact original form, accompanied by English versions from the"
        "1914 translation by H. Rackham.</p> </div><div> <h2>Where can I get"
        "some?</h2> <p>There are many variations of passages of Lorem Ipsum"
        "available, but the majority have suffered alteration in some form, by"
        "injected humour, or randomised words which don't look even slightly"
        "believable. If you are going to use a passage of Lorem Ipsum, you need"
        "to be sure there isn't anything embarrassing hidden in the middle of"
        "text. All the Lorem Ipsum generators on the Internet tend to repeat"
        "predefined chunks as necessary, making this the first true generator"
        "on the Internet. It uses a dictionary of over 200 Latin words,"
        "combined with a handful of model sentence structures, to generate"
        "Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is"
        "therefore always free from repetition, injected humour, or"
        "non-characteristic words etc.</p> </body></html>"
    )


@pytest.fixture(scope="module")
def lipsum_item(lipsum):
    return StaticItem(path=HOME_PATH, content=lipsum, mimetype="text/html")


def test_imports():
    assert libzim.writer.Compression  # noqa
    assert libzim.writer.Blob  # noqa
    assert libzim.writer.Item  # noqa
    assert libzim.writer.ContentProvider  # noqa
    assert libzim.writer.FileProvider  # noqa
    assert libzim.writer.StringProvider  # noqa
    assert libzim.writer.Creator  # noqa


def test_pascalize():
    assert libzim.writer.pascalize("title") == "Title"
    assert libzim.writer.pascalize("my man") == "My Man"
    assert libzim.writer.pascalize("THATisBAD") == "Thatisbad"


def test_creator_filename(fpath):
    with Creator(fpath) as c:
        assert c.filename == fpath
    assert Archive(fpath).filename == fpath


def test_creator_repr(fpath):
    with Creator(fpath) as c:
        assert str(fpath) in str(c)


def get_creator_output(fpath, verbose):
    """run creator with configVerbose(verbose) and return its stdout as str"""
    code = """
from libzim.writer import Creator
with Creator("{fpath}").config_verbose({verbose}) as creator:
    pass
""".replace(
        "{fpath}", str(fpath)
    ).replace(
        "{verbose}", str(verbose)
    )
    ps = subprocess.run(
        [sys.executable, "-c", code],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    assert ps.returncode == 0
    return ps.stdout


@pytest.mark.parametrize("verbose", [(True, False)])
def test_creator_verbose(fpath, verbose):
    output = get_creator_output(fpath, verbose).strip()
    lines = output.splitlines()
    if verbose:
        assert "T:" in output
        assert len(lines) >= 5
    else:
        assert len(lines) == 2


def test_creator_compression(fpath, lipsum_item):
    """make sure we can create ZIM files with various compression algorithms

    also makes sure we're getting different sizes using diffrent alg.
    based on a piece of text that should give different results"""
    filesizes = {}
    for comp in libzim.writer.Compression.__members__.keys():
        fpath_str = fpath.with_name(f"{fpath.name}_{comp}_str.zim")
        with Creator(fpath_str).config_compression(comp) as c:
            c.add_item(lipsum_item)

        fpath_val = fpath.with_name(f"{fpath.name}_{comp}_val.zim")
        comp_val = getattr(libzim.writer.Compression, comp)
        with Creator(fpath_val).config_compression(comp_val) as c:
            c.add_item(lipsum_item)

        assert Archive(fpath_str).checksum
        assert Archive(fpath_str).filesize == Archive(fpath_val).filesize
        filesizes[comp] = Archive(fpath_str).filesize

    for a, b in itertools.combinations(filesizes.keys(), 2):
        assert filesizes[a] != filesizes[b]

    # now don't specify
    with Creator(fpath) as c:
        c.add_item(lipsum_item)

    # default should be zstd
    assert Archive(fpath).filesize == filesizes["zstd"]


@pytest.mark.parametrize("cluster_size", [0, 128, 512, 8196, 10240])
def test_creator_clustersize(fpath, cluster_size, lipsum_item):
    """ensure we can create ZIM with arbitrary min-cluster-size"""
    with Creator(fpath).config_clustersize(cluster_size) as c:
        c.add_item(lipsum_item)


@pytest.mark.parametrize(
    "indexing, language, expected",
    [
        (False, "a", 0),
        (False, "eng", 0),
        (True, "eng", 1),
        (True, "en", 1),
        (True, "fra", 1),
        (True, "fr", 1),
    ],
)
def test_creator_indexing(fpath, lipsum_item, indexing, language, expected):
    with Creator(fpath).config_indexing(indexing, language) as c:
        c.add_item(lipsum_item)

    zim = Archive(fpath)
    assert zim.has_fulltext_index == indexing

    if indexing:
        query = Query().set_query("standard")
        searcher = Searcher(zim)
        search = searcher.search(query)
        assert search.getEstimatedMatches() == expected


@pytest.mark.parametrize("nb_workers", [1, 2, 3, 5])
def test_creator_nbworkers(fpath, lipsum_item, nb_workers):
    with Creator(fpath).config_nbworkers(nb_workers) as c:
        c.add_item(lipsum_item)


def test_creator_combine_config(fpath, lipsum_item):
    with Creator(fpath).config_verbose(True).config_compression(
        "lzma"
    ).config_clustersize(1024).config_indexing(True, "eng").config_nbworkers(2) as c:
        c.add_item(lipsum_item)


@pytest.mark.parametrize(
    "name, args",
    [
        ("verbose", (True,)),
        ("compression", ("lzma",)),
        ("clustersize", (1024,)),
        ("indexing", (True, "eng")),
        ("nbworkers", (2,)),
    ],
)
def test_creator_config_poststart(fpath, name, args):
    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="started"):
            getattr(c, f"config_{name}")(*args)


def test_creator_nocontext(fpath, lipsum_item):
    """ensure we can use the creator linearily"""
    creator = Creator(fpath)
    exc_type, exc_val, exc_tb = None, None, None

    creator.__enter__()
    creator.add_metadata("Name", "name")
    creator.add_item(lipsum_item)
    with pytest.raises(RuntimeError):
        creator.config_verbose(True)
    creator.__exit__(exc_type, exc_val, exc_tb)

    # now with an exception
    creator = Creator(fpath)
    creator.__enter__()
    creator.add_item(lipsum_item)
    try:
        creator.add_redirection("A", HOME_PATH)
    except Exception:
        exc_type, exc_val, exc_tb = sys.exc_info()
        with pytest.raises(TypeError):
            raise
    creator.__exit__(exc_type, exc_val, exc_tb)


def test_creator_subclass(fpath, lipsum_item):
    class ACreator(Creator):
        def __init__(self, fpath, tata):
            super().__init__(filename=fpath)
            self.ready = False

        def __exit__(self, exc_type, exc_val, exc_tb):
            super().__exit__(exc_type, exc_val, exc_tb)
            self.ready = True

    creator = ACreator(fpath, tata=2)
    assert creator.ready is False
    with creator:
        assert creator.ready is False
        creator.add_item(lipsum_item)
    assert creator.ready is True


def test_creator_mainpath(fpath, lipsum_item):
    main_path = HOME_PATH
    with Creator(fpath).set_mainpath(main_path) as c:
        c.add_item(lipsum_item)

    zim = Archive(fpath)
    assert zim.has_main_entry is True
    assert zim.main_entry.path == "mainPage"
    assert zim.main_entry.get_item().path == main_path

    fpath.unlink()

    with Creator(fpath) as c:
        c.add_item(lipsum_item)
    zim = Archive(fpath)
    assert zim.has_main_entry is False
    with pytest.raises(RuntimeError):
        assert zim.main_entry


def test_creator_illustration(fpath, favicon_data):
    with Creator(fpath) as c:
        c.add_illustration(48, favicon_data)
        c.add_illustration(96, favicon_data)

    zim = Archive(fpath)
    assert zim.has_illustration() is True
    assert zim.has_illustration(48) is True
    assert zim.has_illustration(96) is True
    assert zim.has_illustration(128) is False
    assert bytes(zim.get_illustration_item().content) == favicon_data
    assert bytes(zim.get_illustration_item(96).content) == favicon_data
    assert zim.get_illustration_sizes() == {48, 96}


def test_creator_additem(fpath, lipsum_item):
    # ensure we can't add if not started
    c = Creator(fpath)
    with pytest.raises(RuntimeError, match="not started"):
        c.add_item(lipsum_item)
    del c

    with Creator(fpath) as c:
        c.add_item(lipsum_item)
        with pytest.raises(TypeError, match="must not be None"):
            c.add_item(None)
        with pytest.raises(RuntimeError):
            c.add_item("hello")
        with pytest.raises(TypeError, match="takes no keyword arguments"):
            c.add_item(mimetype="text/html")


def test_creator_metadata(fpath, lipsum_item):
    metadata = {
        # kiwix-mandatory
        "Name": "wikipedia_fr_football",
        "Title": "English Wikipedia",
        "Creator": "English speaking Wikipedia contributors",
        "Publisher": "Wikipedia user Foobar",
        "Date": "2009-11-21",
        "Description": "All articles (without images) from the english Wikipedia",
        "Language": "eng",
        # optional
        "Longdescription": (
            "This ZIM file contains all articles (without images) "
            "from the english Wikipedia by 2009-11-10."
            " The topics are ..."
        ),
        "Licence": "CC-BY",
        "Tags": "wikipedia;_category:wikipedia;_pictures:no;"
        "_videos:no;_details:yes;_ftindex:yes",
        "Flavour": "nopic",
        "Source": "https://en.wikipedia.org/",
        "Scraper": "sotoki 1.2.3",
    }

    # ensure we can't add if not started
    c = Creator(fpath)
    with pytest.raises(RuntimeError, match="not started"):
        key = next(iter(metadata.keys()))
        c.add_metadata(key, metadata.get(key))
    del c

    with Creator(fpath) as c:
        c.add_item(lipsum_item)
        for name, value in metadata.items():
            if name == "Date":
                continue
            c.add_metadata(name, value)

        mdate = datetime.date(*[int(x) for x in metadata.get("Date").split("-")])
        c.add_metadata("Date", mdate)

    zim = Archive(fpath)
    for name, value in metadata.items():
        assert zim.get_metadata(name).decode("UTF-8") == value


def test_creator_metadata_overwrite(fpath, lipsum_item, favicon_data):
    """re-adding an Entry (even Metadata) now raises an exception (libzim 7.2+)"""
    with Creator(fpath) as c:
        c.add_item(lipsum_item)
        with pytest.raises(RuntimeError, match="Impossible to add"):
            c.add_item(lipsum_item)

        c.add_metadata("Key", "first")
        with pytest.raises(RuntimeError, match="Impossible to add"):
            c.add_metadata("Key", "second")

        c.add_redirection("home", lipsum_item.get_path(), "Home", {})
        with pytest.raises(RuntimeError, match="Impossible to add"):
            c.add_redirection("home", lipsum_item.get_path(), "Home again", {})

        c.add_illustration(48, favicon_data)
        # this currently segfaults but it should not
        with pytest.raises(RuntimeError, match="Impossible to add"):
            c.add_illustration(48, favicon_data)
    zim = Archive(fpath)
    assert zim.get_metadata("Key").decode("UTF-8") == "first"


def test_creator_redirection(fpath, lipsum_item):
    # ensure we can't add if not started
    c = Creator(fpath)
    with pytest.raises(RuntimeError, match="not started"):
        c.add_redirection("home", "hello", HOME_PATH, {Hint.FRONT_ARTICLE: True})
    del c

    with Creator(fpath) as c:
        c.add_item(lipsum_item)
        c.add_redirection("home", "hello", HOME_PATH, {Hint.FRONT_ARTICLE: True})
        c.add_redirection("accueil", "bonjour", HOME_PATH, {Hint.FRONT_ARTICLE: True})

    zim = Archive(fpath)
    assert zim.entry_count == 3
    assert zim.has_entry_by_path("home") is True
    assert zim.has_entry_by_path("accueil") is True
    assert zim.get_entry_by_path("home").is_redirect
    assert (
        zim.get_entry_by_path("home").get_redirect_entry().path
        == zim.get_entry_by_path(HOME_PATH).path
    )
    assert zim.get_entry_by_path("accueil").get_item().path == HOME_PATH

    # suggestions
    sugg_searcher = SuggestionSearcher(zim)
    sugg_hello = sugg_searcher.suggest("hello")
    assert "home" in list(sugg_hello.getResults(0, sugg_hello.getEstimatedMatches()))
    sugg_bonjour = sugg_searcher.suggest("bonjour")
    assert "accueil" in list(
        sugg_bonjour.getResults(0, sugg_hello.getEstimatedMatches())
    )


def test_item_notimplemented(fpath, lipsum_item):
    item = Item()

    for member in ("path", "title", "mimetype", "contentprovider"):
        with pytest.raises(NotImplementedError):
            getattr(item, f"get_{member}")()

    assert HOME_PATH in str(lipsum_item)
    assert lipsum_item.get_title() in str(lipsum_item)


def test_contentprovider(fpath):
    cp = ContentProvider()
    for member in ("get_size", "gen_blob"):
        with pytest.raises(NotImplementedError):
            getattr(cp, member)()


def test_fileprovider(fpath, lipsum):
    lipsum_fpath = fpath.with_name("lipsum.html")
    with open(lipsum_fpath, "w") as fh:
        for _ in range(0, 10):
            fh.write(lipsum)

    item = StaticItem(path=HOME_PATH, filepath=lipsum_fpath, mimetype="text/html")
    assert HOME_PATH in str(item)
    assert item.get_title() in str(item)

    with Creator(fpath) as c:
        c.add_item(item)

    zim = Archive(fpath)
    with open(lipsum_fpath, "rb") as fh:
        assert bytes(zim.get_entry_by_path(HOME_PATH).get_item().content) == fh.read()

    # test feed streaming
    cp = item.get_contentprovider()
    b = cp.feed()
    while b.size():
        assert isinstance(b, Blob)
        b = cp.feed()


def test_stringprovider(fpath, lipsum):
    item = StaticItem(path=HOME_PATH, content=lipsum, mimetype="text/html")
    assert HOME_PATH in str(item)
    assert item.get_title() in str(item)

    with Creator(fpath) as c:
        c.add_item(item)

    zim = Archive(fpath)
    assert bytes(zim.get_entry_by_path(HOME_PATH).get_item().content) == lipsum.encode(
        "UTF-8"
    )

    # test feed streaming
    cp = item.get_contentprovider()
    b = cp.feed()
    while b.size():
        assert isinstance(b, Blob)
        b = cp.feed()


def test_item_contentprovider_none(fpath):
    class AnItem:
        def get_path(self):
            return ""

        def get_title(self):
            return ""

        def get_mimetype(self):
            return ""

        def get_contentprovider(self):
            return ""

        def get_hints(self):
            return {}

    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="ContentProvider is None"):
            c.add_item(AnItem())


def test_missing_contentprovider(fpath):
    class AnItem:
        def get_path(self):
            return ""

        def get_title(self):
            return ""

        def get_mimetype(self):
            return ""

        def get_hints(self):
            return {}

    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="has no attribute"):
            c.add_item(AnItem())


def test_missing_hints(fpath):
    class AnItem:
        def get_path(self):
            return ""

        def get_title(self):
            return ""

        def get_mimetype(self):
            return ""

    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="has no attribute 'get_hints'"):
            c.add_item(AnItem())

        with pytest.raises(RuntimeError, match="must be implemented"):
            c.add_item(libzim.writer.Item())


def test_nondict_hints(fpath):
    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="has no attribute 'items'"):
            c.add_item(StaticItem(path="1", title="", hints=1))

        with pytest.raises(TypeError, match="hints"):
            c.add_redirection("a", "", "b", hints=1)


def test_hints_values(fpath):
    with Creator(fpath) as c:
        # correct values
        c.add_item(StaticItem(path="0", title="", hints={}))
        c.add_item(
            StaticItem(
                path="1",
                title="",
                hints={Hint.FRONT_ARTICLE: True, Hint.COMPRESS: False},
            )
        )
        # non-expected Hints are ignored
        c.add_item(StaticItem(path="2", title="", hints={"hello": "world"}))
        # Hint values are casted to bool
        c.add_item(StaticItem(path="3", title="", hints={Hint.FRONT_ARTICLE: "world"}))
        c.add_redirection(
            path="4", title="", targetPath="0", hints={Hint.COMPRESS: True}
        )
        # filtered-out values
        c.add_item(StaticItem(path="5", title="", hints={5: True}))
        c.add_item(StaticItem(path="6", title="", hints={"yolo": True}))
        c.add_item(StaticItem(path="7", title="", hints={"FRONT_ARTICLE": True}))
        c.add_item(StaticItem(path="8", title="", hints={0: True}))

        # non-existent Hint
        with pytest.raises(AttributeError, match="YOLO"):
            c.add_item(StaticItem(path="0", title="", hints={Hint.YOLO: True}))

        with pytest.raises(AttributeError, match="YOLO"):
            c.add_redirection(
                path="5", title="", target_path="0", hints={Hint.YOLO: True}
            )


def test_reimpfeed(fpath):
    class AContentProvider:
        def __init__(self):
            self.called = False

        def get_size(self):
            return 1

        def feed(self):
            if self.called:
                return Blob("")
            self.called = True
            return Blob("1")

    class AnItem:
        def get_path(self):
            return "-"

        def get_title(self):
            return ""

        def get_mimetype(self):
            return ""

        def get_hints(self):
            return {}

        def get_contentprovider(self):
            return AContentProvider()

    with Creator(fpath) as c:
        c.add_item(AnItem())

    item = AnItem()
    cp = item.get_contentprovider()
    assert cp.get_size() == 1
    assert cp.feed().size() == 1


def test_virtualmethods_int_exc(fpath):
    class AContentProvider:
        def get_size(self):
            return ""

        def feed(self):
            return Blob("")

    class AnItem:
        def get_path(self):
            return ""

        def get_title(self):
            return ""

        def get_mimetype(self):
            return ""

        def get_hints(self):
            return {}

        def get_contentprovider(self):
            return AContentProvider()

    with Creator(fpath) as c:
        with pytest.raises(RuntimeError, match="TypeError: an integer is required"):
            c.add_item(AnItem())


def test_creator_badfilename(tmpdir):
    # lack of perm
    with pytest.raises(IOError):
        Creator("/root/test.zim")

    # forward slash points to non-existing folder
    with pytest.raises(IOError):
        Creator(tmpdir / "test/test.zim")
