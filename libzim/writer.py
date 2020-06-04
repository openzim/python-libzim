# This file is part of python-libzim
# (see https://github.com/libzim/python-libzim)
#
# Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>
# Copyright (c) 2020 Matthieu Gautier <mgautier@kymeria.fr>
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


import datetime
from collections import defaultdict

from .wrapper import Creator as _Creator
from .wrapper import WritingBlob as Blob

__all__ = ["Article", "Blob", "Creator"]


class Article:
    def __init__(self):
        self._blob = None

    def get_url(self):
        raise NotImplementedError

    def get_title(self):
        raise NotImplementedError

    def is_redirect(self):
        raise NotImplementedError

    def get_mime_type(self):
        raise NotImplementedError

    def get_filename(self):
        raise NotImplementedError

    def should_compress(self):
        raise NotImplementedError

    def should_index(self):
        raise NotImplementedError

    def redirect_url(self):
        raise NotImplementedError

    def _get_data(self):
        if self._blob is None:
            self._blob = self.get_data()
        return self._blob

    def get_data(self):
        raise NotImplementedError


class MetadataArticle(Article):
    def __init__(self, url, metadata_content):
        Article.__init__(self)
        self.url = url
        self.metadata_content = metadata_content

    def is_redirect(self):
        return False

    def get_url(self):
        return f"M/{self.url}"

    def get_title(self):
        return ""

    def get_mime_type(self):
        return "text/plain"

    def get_filename(self):
        return ""

    def should_compress(self):
        return True

    def should_index(self):
        return False

    def get_data(self):
        return Blob(self.metadata_content)


MANDATORY_METADATA_KEYS = [
    "Name",
    "Title",
    "Creator",
    "Publisher",
    "Date",
    "Description",
    "Language",
]


def pascalize(keyword):
    """ Converts python case to pascal case. example: long_description-> LongDescription """
    return "".join(keyword.title().split("_"))


class Creator:
    """
    A class to represent a Zim Creator.

    Attributes
    ----------
    *c_creator : zim.Creator
        a pointer to the C++ Creator object
    _finalized : bool
        flag if the creator was finalized
    _filename : str
        Zim file path
    _main_page : str
        Zim file main page
    _index_language : str
        Zim file Index language
    _min_chunk_size : str
        Zim file minimum chunk size
    _article_counter
        Zim file article counter
    _metadata
        Zim file metadata
    """

    def __init__(self, filename, main_page, index_language, min_chunk_size):
        print(filename)
        self._creatorWrapper = _Creator(filename, main_page, index_language, min_chunk_size)
        self.filename = filename
        self.main_page = main_page
        self.language = index_language
        self._metadata = {}
        self._article_counter = defaultdict(int)
        self.update_metadata(date=datetime.date.today(), language=index_language)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def add_article(self, article):
        self._creatorWrapper.add_article(article)
        if not article.is_redirect():
            self._update_article_counter(article)

    def _update_article_counter(self, article):
        # default dict update
        self._article_counter[article.get_mime_type().strip()] += 1

    def mandatory_metadata_ok(self):
        """Flag if mandatory metadata is complete and not empty"""
        metadata_item_ok = [k in self._metadata for k in MANDATORY_METADATA_KEYS]
        return all(metadata_item_ok)

    def update_metadata(self, **kwargs):
        "Updates article metadata" ""
        new_metadata = {pascalize(k): v for k, v in kwargs.items()}
        self._metadata.update(new_metadata)

    def write_metadata(self):
        for key, value in self._metadata.items():
            if key == "Date" and isinstance(value, datetime.date):
                value = value.strftime("%Y-%m-%d")
            article = MetadataArticle(key, value)
            self._creatorWrapper.add_article(article)

        article = MetadataArticle("Counter", self._get_counter_string())
        self._creatorWrapper.add_article(article)

    def _get_counter_string(self):
        return ";".join(["%s=%s" % (k, v) for (k, v) in self._article_counter.items()])

    def close(self):
        self.write_metadata()
        self._creatorWrapper.finalize()

    def __repr__(self):
        return f"Creator(filename={self.filename})"
