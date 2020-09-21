""" libzim writer module
    - Creator to create ZIM files
    - Article to store ZIM articles metadata
    - Blob to store ZIM article content
    Usage:
    with Creator(pathlib.Path("myfile.zim"), main_page="welcome.html") as xf:
        article = MyArticleSubclass(
            url="A/welcome.html",
            title="My Title",
            content=Blob("My content"))
        zf.add_article(article)
        zf.update_metadata(tags="new;demo") """

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

import pathlib
import datetime
import collections
from typing import Union

from .wrapper import Creator as _Creator, Compression
from .wrapper import WritingBlob as Blob

__all__ = ["Item", "Blob", "Creator", "ContentProvider"]

class ContentProvider:
    def __init__(self):
        self.generator = None

    def get_size(self) -> int:
        """ Size of get_data's result in bytes """
        raise NotImplementedError("get_size must be implemented.")

    def feed(self) -> Blob:
        """ Blob(s) containing the complete content of the article.
            Must return an empty blob to tell writer no more content has to be written.
            Sum(size(blobs)) must be equals to `self.get_size()`
        """
        if self.generator is None:
            self.generator = self.gen_blob()

        try:
            # We have to keep a ref to _blob to be sure gc do not del it while cpp is
            # using it
            self._blob = next(self.generator)
        except StopIteration:
            self._blob = Blob("")

        return self._blob

    def gen_blob(self):
        """ Generator yielding blobs for the content of the article """
        raise NotImplementedError("gen_blob (ro feed) must be implemented")


class Item:
    """ Item stub to override

        Pass a subclass of it to Creator.add_article() """

    def __init__(self):
        self._blob = None

    def get_path(self) -> str:
        """ Full path of item"""
        raise NotImplementedError("get_path must be implemented.")

    def get_title(self) -> str:
        """ Article title. Might be indexed and used in suggestions """
        raise NotImplementedError("get_title must be implemented.")

    def get_mimetype(self) -> str:
        """ MIME-type of the article's content."""
        raise NotImplementedError("get_mimetype must be implemented.")

    def get_contentProvider(self) -> ContentProvider:
        """ Blob containing the complete content of the article """
        raise NotImplementedError("get_contentProvider must be implemented.")

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(path={self.get_path()}, title={self.get_title()})"


def pascalize(keyword: str):
     """ Converts python case to pascal case.
         example: long_description -> LongDescription """
     return "".join(keyword.title().split("_"))


class Creator(_Creator):
    """ Zim Creator.

        Attributes
        ----------
        *_creatorWrapper : wrapper.ZimCreatorWrapper
            a pointer to the C++ Creator object wrapper
        filename : pathlib.Path
            Zim file path
        main_page : str
            Zim file main page (without namespace)
        language : str
            Zim file Index language
        _article_counter
            Zim file article counter
        _metadata
            Zim file metadata """


    def configCompression(self, compression):
        if not isinstance(compression, Compression):
            compression = getattr(Compression, compression.lower())
        super().configCompression(compression)

    def add_metadata(self, name, content):
        name = pascalize(name)
        if name == "Date" and isinstance(content, (datetime.date, datetime.datetime)):
            content = content.strftime("%Y-%m-%d")
        super().add_metadata(name, content)

    def __repr__(self) -> str:
        return f"Creator(filename={self.filename})"
