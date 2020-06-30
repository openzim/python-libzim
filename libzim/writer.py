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

from .wrapper import Creator as _Creator
from .wrapper import WritingBlob as Blob

__all__ = ["Article", "Blob", "Creator"]


class Article:
    """ Article stub to override

        Pass a subclass of it to Creator.add_article() """

    def __init__(self):
        self._blob = None

    def get_url(self) -> str:
        """ Full URL of article including namespace """
        raise NotImplementedError("get_url must be implemented.")

    def get_title(self) -> str:
        """ Article title. Might be indexed and used in suggestions """
        raise NotImplementedError("get_title must be implemented.")

    def is_redirect(self) -> bool:
        """ Whether this redirects to another article (cf. redirec_url) """
        raise NotImplementedError("get_redirect must be implemented.")

    def get_mime_type(self) -> str:
        """ MIME-type of the article's content. A/ namespace reserved to text/html """
        raise NotImplementedError("get_mime_type must be implemented.")

    def get_filename(self) -> str:
        """ Filename to get content from. Blank string "" if not used """
        raise NotImplementedError("get_filename must be implemented.")

    def should_compress(self) -> bool:
        """ Whether the article's content should be compressed or not """
        raise NotImplementedError("should_compress must be implemented.")

    def should_index(self) -> bool:
        """ Whether the article's content should be indexed or not """
        raise NotImplementedError("should_index must be implemented.")

    def get_redirect_url(self) -> str:
        """ Full URL including namespace of another article """
        raise NotImplementedError("get_redirect_url must be implemented.")

    def _get_data(self) -> Blob:
        """ Internal data-retrieval with a cache to the content's pointer

            You don't need to override this """
        if self._blob is None:
            self._blob = self.get_data()
        return self._blob

    def get_data(self) -> Blob:
        """ Blob containing the complete content of the article """
        raise NotImplementedError("get_data must be implemented.")

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(url={self.get_url()}, title={self.get_title()})"


class MetadataArticle(Article):
    """ Simple Article sub-class for key-value articles on M/ metadata namespace """

    def __init__(self, url: str, metadata_content: str):
        Article.__init__(self)
        self.url = url
        self.metadata_content = metadata_content

    def is_redirect(self) -> bool:
        return False

    def get_url(self) -> str:
        return f"M/{self.url}"

    def get_title(self) -> str:
        return ""

    def get_mime_type(self) -> str:
        return "text/plain"

    def get_filename(self) -> str:
        return ""

    def should_compress(self) -> bool:
        return True

    def should_index(self) -> bool:
        return False

    def get_data(self) -> Blob:
        return Blob(self.metadata_content)


class Creator:
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

    def __init__(
        self, filename: pathlib.Path, main_page: str, index_language: str = "eng", min_chunk_size: int = 2048,
    ):
        """ Creates a ZIM Creator

            Parameters
            ----------
            filename : Path to create the ZIM file at
            main_page: ZIM file main article URL (without namespace, must be in A/)
            index_language: content language to inform indexer with (ISO-639-3)
            min_chunk_size: minimum size of chunks for compression """

        self._creatorWrapper = _Creator(str(filename), main_page, index_language, min_chunk_size)
        self.filename = pathlib.Path(filename)
        self.main_page = main_page
        self.language = index_language
        self._metadata = {}
        self._article_counter = collections.defaultdict(int)
        self.update_metadata(date=datetime.date.today(), language=index_language)
        self._closed = False

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def __del__(self):
        if not self._closed:
            self.close()

    def add_article(self, article: Article):
        """ Adds an article to the Creator.

            Parameters
            ----------
            article : Zim writer Article
                The article to add to the file
            Raises
            ------
                RuntimeError
                    If the ZimCreator was already finalized """
        self._creatorWrapper.add_article(article)
        if not article.is_redirect():
            # update article counter
            self._article_counter[article.get_mime_type().strip()] += 1

    def update_metadata(self, **kwargs: str):
        """ Updates Creator metadata for ZIM, supplied as keyword arguments """

        def pascalize(keyword: str):
            """ Converts python case to pascal case.

                example: long_description -> LongDescription """
            return "".join(keyword.title().split("_"))

        self._metadata.update({pascalize(k): v for k, v in kwargs.items()})

    def close(self):
        """ Finalizes and writes added articles to the file

            Raises
            ------
                RuntimeError
                    If the ZimCreator was already finalized """
        if self._closed:
            raise RuntimeError("Creator already closed")

        # Store _medtadata dict as MetadataArticle
        for key, value in self._metadata.items():
            if key == "Date" and isinstance(value, (datetime.date, datetime.datetime)):
                value = value.strftime("%Y-%m-%d")
            article = MetadataArticle(key, value)
            self._creatorWrapper.add_article(article)

        counter_str = ";".join([f"{k}={v}" for (k, v) in self._article_counter.items()])
        article = MetadataArticle("Counter", counter_str)
        self._creatorWrapper.add_article(article)

        self._creatorWrapper.finalize()
        self._closed = True

    def __repr__(self) -> str:
        return f"Creator(filename={self.filename})"
