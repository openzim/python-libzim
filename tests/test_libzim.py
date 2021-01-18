# This file is part of python-libzim
# (see https://github.com/libzim/python-libzim)
#
# Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

import re
import pathlib

import pytest

from libzim.writer import Item, Blob, Creator, Compression, ContentProvider
from libzim.reader import Archive

# test files https://wiki.kiwix.org/wiki/Content_in_all_languages


# https://wiki.openzim.org/wiki/Metadata
@pytest.fixture(scope="session")
def metadata():
    return {
        # Mandatory
        "Name": "wikipedia_fr_football",
        "Title": "English Wikipedia",
        "Creator": "English speaking Wikipedia contributors",
        "Publisher": "Wikipedia user Foobar",
        "Date": "2009-11-21",
        "Description": "All articles (without images) from the english Wikipedia",
        "Language": "eng",
        # Optional
        "Longdescription": (
            "This ZIM file contains all articles (without images) from the english Wikipedia by 2009-11-10."
            " The topics are ..."
        ),
        "Licence": "CC-BY",
        "Tags": "wikipedia;_category:wikipedia;_pictures:no;_videos:no;_details:yes;_ftindex:yes",
        "Flavour": "nopic",
        "Source": "https://en.wikipedia.org/",
        "Counter": "image/jpeg=5;image/gif=3;image/png=2",
        "Scraper": "sotoki 1.2.3",
    }


@pytest.fixture(scope="session")
def item_content():
    content = """<!DOCTYPE html>
        <html class="client-js">
        <head><meta charset="UTF-8">
        <title>Monadical</title>
        </head>
        <h1> ñññ Hello, it works ñññ </h1></html>"""
    path = "Monadical_SAS"
    title = "Monadical SAS"
    mime_type = "text/html"
    return (content, path, title, mime_type)


class SimpleItem(Item):
    def __init__(self, content, path, title, mime_type):
        self.content = content
        self.path = path
        self.title = title
        self.mime_type = mime_type

    def get_path(self):
        return self.path

    def get_title(self):
        return self.title

    def get_mimetype(self):
        return self.mime_type

    def get_contentProvider(self):
        return SimpleContentProvider(self.content)


class SimpleContentProvider(ContentProvider):
    def __init__(self, content):
        super().__init__()
        self.content = content

    def gen_blob(self):
        yield Blob(self.content)

    def get_size(self):
        return len(self.content.encode("utf8"))


class OverridenItem(Item):
    def get_path(self) -> str:
        return "N/u"

    def get_title(self) -> str:
        return ""

    def get_mimetype(self) -> str:
        return "text/plain"


@pytest.fixture(scope="session")
def item(item_content):
    return SimpleItem(*item_content)


def test_write_article(tmpdir, item):
    zim_creator = Creator(tmpdir / "test.zim")
    with zim_creator:
        zim_creator.add_item(item)


def test_creator_config(tmpdir, item):
    # Do with intermediate steps
    zim_creator = Creator(tmpdir / "test.zim")
    zim_creator.configIndexing(True, "eng")
    zim_creator.setMainPath("welcome")
    with zim_creator:
        zim_creator.add_item(item)
        zim_creator.add_metadata("creator", b"python-libzim")
    del zim_creator

    # Do it all in once:
    with Creator(tmpdir / "test.zim").configIndexing(True, "end") as zim_creator:
        zim_creator.setMainPath("welcome")
        zim_creator.add_item(item)
        zim_creator.add_metadata("creator", b"python-libzim")


def test_creator_params(tmpdir):
    path = tmpdir / "test.zim"
    zim_creator = Creator(path)
    zim_creator.configIndexing(True, "eng")
    main_page = "welcome"
    with zim_creator:
        zim_creator.add_item(SimpleItem(title="Welcome", mime_type="text/html", content="", path=main_page))
        zim_creator.add_metadata("language", b"eng")
        zim_creator.setMainPath(main_page)

    archive = Archive(path)
    assert archive.filename == path
    assert archive.main_entry.path == "mainPage"
    assert archive.main_entry.get_redirect_entry().path == main_page
    assert archive.get_metadata("Language") == b"eng"


def test_segfault_on_realloc(tmpdir):
    """ assert that we are able to delete an unclosed Creator #31 """
    zim_creator = Creator(tmpdir / "test.zim")
    del zim_creator  # used to segfault


def test_noleftbehind_empty(tmpdir):
    """ assert that ZIM with no articles don't leave files behind #41 """
    fname = "test_empty.zim"
    with Creator(tmpdir / fname) as zim_creator:
        print(zim_creator)

    assert len([p for p in tmpdir.listdir() if p.basename.startswith(fname)]) == 1


def test_filename_param_types(tmpdir):
    path = tmpdir / "test.zim"
    with Creator(path) as zim_creator:
        assert zim_creator.filename == path
        assert isinstance(zim_creator.filename, pathlib.Path)
    with Creator(str(path)) as zim_creator:
        assert zim_creator.filename == path
        assert isinstance(zim_creator.filename, pathlib.Path)


def test_in_article_exceptions(tmpdir):
    """ make sure we raise RuntimeError from article's virtual methods """

    class StringErrorArticle(SimpleItem):
        def get_path(self):
            raise IOError

    class BlobErrorArticle(SimpleItem):
        def get_contentProvider(self):
            raise IOError

    path = tmpdir / "test.zim"
    args = {"title": "Hello", "mime_type": "text/html", "content": "", "path": "welcome"}

    with Creator(path) as zim_creator:
        # make sure we can can exception of all types (except int, not used)
        with pytest.raises(RuntimeError, match="in get_path"):
            zim_creator.add_item(StringErrorArticle(**args))
        with pytest.raises(RuntimeError, match="IOError"):
            zim_creator.add_item(BlobErrorArticle(**args))
        with pytest.raises(RuntimeError, match="NotImplementedError"):
            zim_creator.add_item(Item())

    # make sure we can catch it from outside creator
    with pytest.raises(RuntimeError):
        with Creator(path) as zim_creator:
            zim_creator.add_item(BlobErrorArticle(**args))


# def test_dontcreatezim_onexception(tmpdir):
#    """ make sure we can prevent ZIM file creation (workaround missing cancel())
#
#        A new interpreter is instanciated to get a different memory space.
#        This workaround is not safe and may segfault at GC under some circumstances
#
#        Unless we get a proper cancel() on libzim, that's the only way to not create
#        a ZIM file on error """
#    path, main_page = tmpdir / "test.zim", "welcome"
#    pycode = f"""
# from libzim.writer import Creator
##
# class BlobErrorArticle:
#    def get_data(self):
#        raise ValueError
#
# with Creator("{path}") as zim_creator:
#    try:
#        zim_creator.add_item(BlobErrorArticle())
#    except:
#        pass
# """
#
#    py = subprocess.run([sys.executable, "-c", pycode])
#    assert py.returncode == 0
#    assert not path.exists()
#


def test_redirect_url(tmpdir):
    itemPath = "welcome"
    redirect_path = "home"

    path = tmpdir / "test.zim"
    with Creator(path) as zim_creator:
        zim_creator.add_item(SimpleItem(title="Hello", mime_type="text/html", content="", path=itemPath))
        zim_creator.add_redirection(path=redirect_path, title="", targetPath=itemPath)

    archive = Archive(path)
    redirectEntry = archive.get_entry_by_path(redirect_path)
    assert redirectEntry.is_redirect
    assert redirectEntry.get_redirect_entry().path == itemPath


@pytest.mark.parametrize(
    "no_method",
    [m for m in dir(SimpleItem) if m.split("_", 1)[0] in ("get", "is", "should")],
)
def test_article_overriding_required(tmpdir, monkeypatch, no_method):
    """ ensure we raise properly on not-implemented methods of Article """

    path = tmpdir / "test.zim"
    pattern = re.compile(r"NotImplementedError.+must be implemented")
    monkeypatch.delattr(SimpleItem, no_method)

    with pytest.raises(RuntimeError, match=pattern):
        with Creator(path) as zim_creator:
            zim_creator.add_item(SimpleItem(content=b"", path="foo", title="", mime_type=""))


def test_repr():
    title = "Welcome !"
    url = "welcome"
    article = SimpleItem("", url, title, "text/plain")
    assert title in repr(article)
    assert url in repr(article)


@pytest.mark.parametrize(
    "compression",
    Compression.__members__,
)
def test_compression_from_enum(tmpdir, compression):
    zim_creator = Creator(tmpdir / "test.zim")
    zim_creator.configCompression(compression)
    with zim_creator:
        zim_creator.add_item(SimpleItem(title="Hello", mime_type="text/html", content="", path="A/home"))


@pytest.mark.parametrize(
    "compression",
    Compression.__members__.keys(),
)
def test_compression_from_string(tmpdir, compression):
    creator = Creator(tmpdir / "test.zim")
    creator.configCompression(compression)
    with creator:
        creator.add_item(SimpleItem(title="Hello", mime_type="text/html", content="", path="A/home"))


def test_bad_compression(tmpdir):
    creator = Creator(tmpdir / "test.zim")
    with pytest.raises(AttributeError):
        creator.configCompression("toto")


def test_filename_article(tmpdir):
    class FileProvider(ContentProvider):
        def __init__(self, fpath):
            super().__init__()
            self.fpath = fpath

        def get_size(self):
            return self.fpath.stat().size

        def gen_blob(self):
            yield Blob(self.fpath.read())

    class FileItem:
        def __init__(self, fpath, path):
            self.fpath = fpath
            self.path = path

        def get_path(self):
            return self.path

        def get_title(self):
            return ""

        def get_mimetype(self):
            return "text/plain"

        def get_contentProvider(self):
            return FileProvider(self.fpath)

    zim_path = tmpdir / "test.zim"
    article_path = tmpdir / "test.txt"
    article_url = "home"
    content = b"abc"

    # write content to physical file
    with open(article_path, "wb") as fh:
        fh.write(content)

    with Creator(zim_path) as zim_creator:
        zim_creator.add_item(FileItem(article_path, article_url))

    # ensure size on reader is correct
    archive = Archive(zim_path)
    assert bytes(archive.get_entry_by_path(article_url).get_item().content) == content
