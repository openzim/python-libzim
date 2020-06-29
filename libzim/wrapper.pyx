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


cimport libzim.wrapper as wrapper

from typing import Generator
from cython.operator import dereference, preincrement
from cpython.ref cimport PyObject
from cpython.buffer cimport PyBUF_WRITABLE

from libc.stdint cimport uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared, unique_ptr

import pathlib
import datetime
import traceback


#########################
#         Blob          #
#########################

cdef class WritingBlob:
    cdef wrapper.Blob* c_blob
    cdef bytes ref_content

    def __cinit__(self, content):
        if isinstance(content, str):
            self.ref_content = content.encode('UTF-8')
        else:
            self.ref_content = content
        self.c_blob = new wrapper.Blob(<char *> self.ref_content, len(self.ref_content))

    def __dealloc__(self):
        if self.c_blob != NULL:
            del self.c_blob

cdef Py_ssize_t itemsize = 1

cdef class ReadingBlob:
    cdef wrapper.Blob c_blob
    cdef Py_ssize_t size
    cdef int view_count

    cdef __setup(self, wrapper.Blob blob):
        """Assigns an internal pointer to the wrapped C++ article object.

        Parameters
        ----------
        *art : Article
            Pointer to a C++ (zim::) article object
        """
        # Set new internal C zim.ZimArticle article
        self.c_blob = blob
        self.size = blob.size()
        self.view_count = 0

    def __dealloc__(self):
        if self.view_count:
            raise RuntimeError("Blob has views")

    def __getbuffer__(self, Py_buffer *buffer, int flags):
        if flags&PyBUF_WRITABLE:
            raise BufferError("Cannot create writable memoryview on readonly data")
        buffer.obj = self
        buffer.buf = <void*>self.c_blob.data()
        buffer.len = self.size
        buffer.readonly = 1
        buffer.format = 'c'
        buffer.internal = NULL                  # see References
        buffer.itemsize = itemsize
        buffer.ndim = 1
        buffer.shape = &self.size
        buffer.strides = &itemsize
        buffer.suboffsets = NULL                # for pointer arrays only

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer *buffer):
        self.view_count -= 1


#------- ZimArticle pure virtual methods --------

cdef public api:
    string string_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a string"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            ret_str = func()
            return ret_str.encode('UTF-8')
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')
        return b""

    wrapper.Blob blob_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a Blob"""
        cdef WritingBlob blob

        try:
            func = getattr(obj, method.decode('UTF-8'))
            blob = func()
            if blob is None:
                raise RuntimeError("Blob is none")
            return dereference(blob.c_blob)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return Blob()

    bool bool_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a bool"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            return func()
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')
        return False

    uint64_t int_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning an int"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            return <uint64_t>func()
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return 0

cdef class Creator:
    """ Zim Creator

        Attributes
        ----------
        *c_creator : zim.ZimCreatorWrapper
            a pointer to the C++ Creator object
        _finalized : bool
            flag if the creator was finalized """

    cdef wrapper.ZimCreatorWrapper *c_creator
    cdef bool _finalized

    def __cinit__(self, str filename: str, str main_page: str = "", str index_language: str = "eng", min_chunk_size: int = 2048):
        """ Constructs a Zim Creator from parameters.

            Parameters
            ----------
            filename : str
                Zim file path
            main_page : str
                Zim file main page (without namespace, must be in A/)
            index_language : str
                Zim file index language (default eng)
            min_chunk_size : int
                Minimum chunk size (default 2048) """

        self.c_creator = wrapper.ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self._finalized = False

    def __dealloc__(self):
        del self.c_creator

    def add_article(self, article not None):
        """ Add an article to the Creator object.

            Parameters
            ----------
            article : ZimArticle
                The article to add to the file
            Raises
            ------
                RuntimeError
                    If the ZimCreator was already finalized """
        if self._finalized:
            raise RuntimeError("ZimCreator already finalized")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object
        cdef shared_ptr[wrapper.ZimArticleWrapper] art = shared_ptr[wrapper.ZimArticleWrapper](
            new wrapper.ZimArticleWrapper(<PyObject*>article));
        with nogil:
            self.c_creator.addArticle(art)

    def finalize(self):
        """ Finalize creation and write added articles to the file.

            Raises
            ------
                RuntimeError
                    If the ZimCreator was already finalized """
        if  self._finalized:
            raise RuntimeError("ZimCreator already finalized")
        with nogil:
            self.c_creator.finalize()
        self._finalized = True

########################
#     ReadArticle      #
########################

cdef class ReadArticle:
    """ Article in a Zim file

        Attributes
        ----------
        *c_article : Article (zim::)
            a pointer to the C++ article object """
    cdef wrapper.Article c_article
    cdef ReadingBlob _blob
    cdef bool _haveBlob

    #def __eq__(self, other):
    #    if isinstance(other, ZimArticle):
    #        return (self.longurl == other.longurl) and (self.content == other.content) and (self.is_redirect == other.is_redirect)
    #    return False

    def __cinit__(self):
        self._haveBlob = False

    cdef __setup(self, wrapper.Article art):
        """ Assigns an internal pointer to the wrapped C++ article object.

            Parameters
            ----------
            *art : Article
                Pointer to a C++ (zim::) article object """
        # Set new internal C zim.ZimArticle article
        self.c_article = art
        self._blob = None

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(wrapper.Article art):
        """ Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            art : Article
                A C++ Article read with File
            Returns
            ------
            ReadArticle
                Casted article """
        cdef ReadArticle article = ReadArticle()
        article.__setup(art)
        return article

    @property
    def namespace(self) -> str:
        """ Article's namespace -> str """
        ns = self.c_article.getNamespace()
        return chr(ns)

    @property
    def title(self) -> str:
        """ Article's title -> str """
        return self.c_article.getTitle().decode('UTF-8')

    @property
    def content(self) -> memoryview:
        """ Article's content -> memoryview """
        if not self._haveBlob:
            self._blob = ReadingBlob()
            self._blob.__setup(self.c_article.getData(<int> 0))
            self._haveBlob = True
        return memoryview(self._blob)

    @property
    def longurl(self) -> str:
        """ Article's long url, including namespace -> str"""
        return self.c_article.getLongUrl().decode("UTF-8", "strict")

    @property
    def url(self) -> str:
        """ Article's url without namespace -> str """
        return self.c_article.getUrl().decode("UTF-8", "strict")

    @property
    def mimetype(self) -> str:
        """ Article's mimetype -> str """
        return self.c_article.getMimeType().decode('UTF-8')

    @property
    def is_redirect(self) -> bool:
        """ Whether article is a redirect -> bool """
        return self.c_article.isRedirect()

    def get_redirect_article(self) -> ReadArticle:
        """ Target ReadArticle of this one -> ReadArticle """
        if not self.is_redirect:
            raise RuntimeError("Article is not a redirect")

        cdef wrapper.Article art = self.c_article.getRedirectArticle()
        if not art.good():
            raise RuntimeError("Redirect article not found")

        article = ReadArticle.from_read_article(art)
        return article

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.longurl}, title={self.title})"




#########################
#        File           #
#########################

cdef class FilePy:
    """ Zim File Reader

        Attributes
        ----------
        *c_file : File
            a pointer to a C++ File object
        _filename : pathlib.Path
            the file name of the File Reader object """

    cdef wrapper.File *c_file
    cdef object _filename

    def __cinit__(self, object filename: pathlib.Path):
        """ Constructs a File from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file """

        self.c_file = new wrapper.File(str(filename).encode('UTF-8'))
        self._filename = pathlib.Path(self.c_file.getFilename().decode("UTF-8", "strict"))

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    @property
    def filename(self) -> pathlib.Path:
        """ Filename of the File object -> pathlib.Path """
        return self._filename

    def get_article(self, url: str) -> ReadArticle:
        """ ReadArticle with a copy of the file article by full url (including namespace) -> ReadArticle

            Parameters
            ----------
            url : str
                The full url, including namespace, of the article
            Returns
            -------
            ReadArticle
                The ReadArticle object
            Raises
            ------
                KeyError
                    If an article with the provided long url is not found in the file """
        # Read to a zim::Article
        cdef wrapper.Article art = self.c_file.getArticleByUrl(url.encode('UTF-8'))
        if not art.good():
            raise KeyError("Article not found for url")

        article = ReadArticle.from_read_article(art)
        return article

    def get_metadata(self, name: str) -> bytes:
        """ A Metadata's content -> bytes

            Parameters
            ----------
            name: str
                url of the metadata article (without namespace)
            Returns
            -------
            bytes
                Metadata article's content. Can be of any type. """
        return bytes(self.get_article(f"M/{name}").content)

    def get_article_by_id(self, article_id: int) -> ReadArticle:
        """ ReadArticle with a copy of the file article by article id -> ReadArticle

        Parameters
        ----------
        article_id : int
            The id of the article
        Returns
        -------
        ReadArticle
            The ReadArticle object
        Raises
        ------
            RuntimeError
                If there is a problem in retrieving article
            IndexError
                If an article with the provided id is not found (id out of bound) """

        # Read to a zim::Article
        cdef wrapper.Article art
        try:
            art = self.c_file.getArticle(<int> article_id)
        except RuntimeError as exc:
            raise(IndexError(exc))
        if not art.good():
            raise IndexError("Article not found for id")

        article = ReadArticle.from_read_article(art)
        return article

    @property
    def main_page_url(self) -> str:
        """ File's main page full url -> str

            Returns
            -------
            str
                The url of the main page, including namespace """
        cdef wrapper.Fileheader header = self.c_file.getFileheader()
        cdef wrapper.Article article
        if header.hasMainPage():
            article = self.c_file.getArticle(header.getMainPage())
            return article.getLongUrl().decode("UTF-8", "strict");

        # TODO Ask about the old format, check libzim for tests
        # Handle old zim where header has no mainPage.
        # (We need to get first article in the zim)
        article = self.c_file.getArticle(<int> 0)
        if article.good():
            return article.getLongUrl().decode("UTF-8", "strict")

    @property
    def checksum(self) -> str:
        """ File's checksum -> str

            Returns
            -------
            str
                The file's checksum """
        return self.c_file.getChecksum().decode("UTF-8", "strict")

    @property
    def article_count(self) -> int:
        """ File's articles count -> int

            Returns
            -------
            int
                The total number of articles in the file """
        return self.c_file.getCountArticles()

    @property
    def namespaces(self) -> str:
        """ Namespaces present in the file -> str

        Returns
        -------
        str
            A string containing initials of all namespaces in the file (ex: "-AIMX") """
        return self.c_file.getNamespaces().decode("UTF-8", "strict")

    def get_namespace_count(self, str ns) -> int:
        """ Articles count within a namespace -> int

            Returns
            -------
            int
                The total number of articles in the namespace """
        return self.c_file.getNamespaceCount(ord(ns[0]))

    def suggest(self, query: str, start: int = 0, end: int = 10) -> Generator[str, None, None]:
        """ Full urls of suggested articles in the file from a title query -> Generator[str, None, None]

            Parameters
            ----------
            query : str
                Title query string
            start : int
                Iterator start (default 0)
            end : end
                Iterator end (default 10)
            Returns
            -------
            Generator
                Url of suggested article """
        cdef unique_ptr[wrapper.Search] search = self.c_file.suggestions(query.encode('UTF-8'),start, end)
        cdef wrapper.search_iterator it = dereference(search).begin()

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def search(self, query: str, start: int = 0, end: int = 10) -> Generator[str, None, None]:
        """ Full urls of articles in the file from a search query -> Generator[str, None, None]

            Parameters
            ----------
            query : str
                Query string
            start : int
                Iterator start (default 0)
            end : end
                Iterator end (default 10)
            Returns
            -------
            Generator
                Url of article matching the search query """

        cdef unique_ptr[wrapper.Search] search = self.c_file.search(query.encode('UTF-8'),start, end)
        cdef wrapper.search_iterator it = dereference(search).begin()

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def get_search_results_count(self, query: str) -> int:
        """ Number of search results for a query -> int

            Parameters
            ----------
            query : str
                Query string
            Returns
            -------
            int
                Number of search results """
        cdef unique_ptr[wrapper.Search] search = self.c_file.search(query.encode('UTF-8'),0, 1)
        return dereference(search).get_matches_estimated()

    def get_suggestions_results_count(self, query: str) -> int:
        """ Number of suggestions for a query -> int

            Parameters
            ----------
            query : str
                Query string
            Returns
            -------
            int
                Number of article suggestions """
        cdef unique_ptr[wrapper.Search] search = self.c_file.suggestions(query.encode('UTF-8'),0 , 1)
        return dereference(search).get_matches_estimated()

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(filename={self.filename})"
