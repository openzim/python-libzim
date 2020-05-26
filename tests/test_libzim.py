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

import pytest

from libzim.writer import Article, Blob, Creator

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
def article_content():
    content = """<!DOCTYPE html>
        <html class="client-js">
        <head><meta charset="UTF-8">
        <title>Monadical</title>
        </head>
        <h1> ñññ Hello, it works ñññ </h1></html>"""
    url = "A/Monadical_SAS"
    title = "Monadical SAS"
    mime_type = "text/html"
    return (content, url, title, mime_type)


class SimpleArticle(Article):
    def __init__(self, content, url, title, mime_type):
        Article.__init__(self)
        self.content = content
        self.url = url
        self.title = title
        self.mime_type = mime_type

    def is_redirect(self):
        return False

    @property
    def can_write(self):
        return True

    def get_url(self):
        return self.url

    def get_title(self):
        return self.title

    def get_mime_type(self):
        return self.mime_type

    def get_filename(self):
        return ""

    def should_compress(self):
        return True

    def should_index(self):
        return True

    def get_data(self):
        return Blob(self.content.encode("UTF-8"))


@pytest.fixture(scope="session")
def article(article_content):
    return SimpleArticle(*article_content)


def test_write_article(tmpdir, article):
    with Creator(
        str(tmpdir / "test.zim"), main_page="welcome", index_language="eng", min_chunk_size=2048,
    ) as zim_creator:
        zim_creator.add_article(article)
        zim_creator.update_metadata(
            creator="python-libzim",
            description="Created in python",
            name="Hola",
            publisher="Monadical",
            title="Test Zim",
        )


def test_article_metadata(tmpdir, metadata):
    with Creator(
        str(tmpdir / "test.zim"), main_page="welcome", index_language="eng", min_chunk_size=2048,
    ) as zim_creator:
        zim_creator.update_metadata(**metadata)
        assert zim_creator._metadata == metadata


def test_check_mandatory_metadata(tmpdir):
    with Creator(
        str(tmpdir / "test.zim"), main_page="welcome", index_language="eng", min_chunk_size=2048,
    ) as zim_creator:
        assert not zim_creator.mandatory_metadata_ok()
        zim_creator.update_metadata(
            creator="python-libzim",
            description="Created in python",
            name="Hola",
            publisher="Monadical",
            title="Test Zim",
        )
        assert zim_creator.mandatory_metadata_ok()
