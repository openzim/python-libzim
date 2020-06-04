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

from cython.operator import dereference, preincrement
from cpython.ref cimport PyObject
from cpython.buffer cimport PyBUF_WRITABLE

from libc.stdint cimport uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared, unique_ptr

import datetime

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


#------ Helper for pure virtual methods --------

cdef get_article_method_from_object(object obj, string method, int *error) with gil:
    try:
        func = getattr(obj, method.decode('UTF-8'))
    except AttributeError:
        error[0] = 1
        raise
    else:
        error[0] = 0
        return func

#------- ZimArticle pure virtual methods --------

cdef public api:
    string string_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a string"""
        func = get_article_method_from_object(obj, method, error)
        ret_str = func()
        return ret_str.encode('UTF-8')

    wrapper.Blob blob_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a Blob"""
        cdef WritingBlob blob

        func = get_article_method_from_object(obj, method, error)
        blob = func()
        return dereference(blob.c_blob)

    bool bool_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a bool"""
        func = get_article_method_from_object(obj, method, error)
        return func()

    uint64_t int_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning an int"""
        func = get_article_method_from_object(obj, method, error)
        return <uint64_t> func()

cdef class Creator:
    """
    A class to represent a Zim Creator.

    Attributes
    ----------
    *c_creator : zim.ZimCreator
        a pointer to the C++ Creator object
    _finalized : bool
        flag if the creator was finalized
    """

    cdef wrapper.ZimCreatorWrapper *c_creator
    cdef bool _finalized

    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        """Constructs a ZimCreator from parameters.
        Parameters
        ----------
        filename : str
            Zim file path
        main_page : str
            Zim file main page
        index_language : str
            Zim file index language (default eng)
        min_chunk_size : int
            Minimum chunk size (default 2048)
        """

        self.c_creator = wrapper.ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self._finalized = False

    def __dealloc__(self):
        del self.c_creator

    def add_article(self, article not None):
        """Add a article to the Creator object.

        Parameters
        ----------
        article : ZimArticle
            The article to add to the file
        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """
        if self._finalized:
            raise RuntimeError("ZimCreator already finalized")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object
        cdef shared_ptr[wrapper.ZimArticleWrapper] art = shared_ptr[wrapper.ZimArticleWrapper](
            new wrapper.ZimArticleWrapper(<PyObject*>article));
        with nogil:
            self.c_creator.addArticle(art)

    def finalize(self):
        """finalize and write added articles to the file.

        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """
        if  self._finalized:
            raise RuntimeError("ZimCreator already finalized")
        with nogil:
            self.c_creator.finalize()
        self._finalized = True

########################
#     ReadArticle      #
########################

cdef class ReadArticle:
    """
    A class to represent a Zim File Article.

    Attributes
    ----------
    *c_article : Article (zim::)
        a pointer to the C++ article object

    Properties
    -----------
    namespace : str
        the article namespace
    title : str
        the article title
    content : str
        the article content
    longurl : str
        the article long url i.e {NAMESPACE}/{redirect_url}
    url : str
        the article url
    mimetype : str
        the article mimetype
    is_redirect : bool
        flag if the article is a redirect

    Methods
    -------
    from_read_article(zim.Article art)
        Creates a python ZimArticle from a C++ zim.Article article.
    """
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
        """Assigns an internal pointer to the wrapped C++ article object.

        Parameters
        ----------
        *art : Article
            Pointer to a C++ (zim::) article object
        """
        # Set new internal C zim.ZimArticle article
        self.c_article = art
        self._blob = None



    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(wrapper.Article art):
        """Creates a python ZimFileArticle from a C++ Article (zim::).

        Parameters
        ----------
        art : Article
            A C++ Article read with File
        Return
        ------

        """
        cdef ReadArticle article = ReadArticle()
        article.__setup(art)
        return article

    @property
    def namespace(self):
        """Get the article's namespace"""
        ns = self.c_article.getNamespace()
        return chr(ns)

    @property
    def title(self):
        """Get the article's title"""
        return self.c_article.getTitle().decode('UTF-8')

    @property
    def content(self):
        """Get the article's content"""
        if not self._haveBlob:
            self._blob = ReadingBlob()
            self._blob.__setup(self.c_article.getData(<int> 0))
            self._haveBlob = True
        return memoryview(self._blob)

    @property
    def longurl(self):
        """Get the article's long url i.e {NAMESPACE}/{url}"""
        return self.c_article.getLongUrl().decode("UTF-8", "strict")

    @property
    def url(self):
        """Get the article's url"""
        return self.c_article.getUrl().decode("UTF-8", "strict")

    @property
    def mimetype(self):
        """Get the article's mimetype"""
        return self.c_article.getMimeType().decode('UTF-8')

    @property
    def is_redirect(self):
        """Get if the article is a redirect"""
        return self.c_article.isRedirect()

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.longurl}, title=)"




#########################
#        File           #
#########################

cdef class FilePy:
    """
    A class to represent a Zim File Reader.

    Attributes
    ----------
    *c_file : File
        a pointer to a C++ File object
    _filename : str
        the file name of the File Reader object
    """

    cdef wrapper.File *c_file
    cdef object _filename

    def __cinit__(self, str filename):
        """Constructs a File from full zim file path.
        Parameters
        ----------
        filename : str
            Full path to a zim file
        """

        self.c_file = new wrapper.File(filename.encode('UTF-8'))
        self._filename = self.c_file.getFilename().decode("UTF-8", "strict")

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    @property
    def filename(self):
        """Get the filename of the File object"""
        return self._filename

    def get_article(self, url):
        """Get a Article with a copy of the file article by full url i.e including namespace

        Parameters
        ----------
        url : str
            The full url, including namespace, of the article
        Returns
        -------
        Article
            The Article object
        Raises
        ------
            RuntimeError
                If an article with the provided long url is not found in the file
        """
        # Read to a zim::Article
        cdef wrapper.Article art = self.c_file.getArticleByUrl(url.encode('UTF-8'))
        if not art.good():
            raise RuntimeError("Article not found for url")

        article = ReadArticle.from_read_article(art)
        return article

    def get_metadata(self, name):
        """Get the file metadata.
        Returns
        -------
        dict
            A dictionary with the file metadata
        """
        article = self.get_article(f"M/{name}")
        return article.content

    def get_article_by_id(self, id):
        """Get a ZimFileArticle with a copy of the file article by article id.

        Parameters
        ----------
        id : int
            The id of the article
        Returns
        -------
        ZimFileArticle
            The ZimFileArticle object
        Raises
        ------
            RuntimeError
                If an article with the provided id is not found in the file
        """

        # Read to a zim::Article
        cdef wrapper.Article art = self.c_file.getArticle(<int> id)
        if not art.good():
            raise RuntimeError("Article not found for id")

        article = ReadArticle.from_read_article(art)
        return article

    @property
    def main_page_url(self):
        """Get the file main page url.
        Returns
        -------
        str
            The url of the main page
        TODO Check old formats
        """
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
    def checksum(self):
        """Get the file checksum.
        Returns
        -------
        str
            The file checksum
        """
        return self.c_file.getChecksum().decode("UTF-8", "strict")

    @property
    def article_count(self):
        """Get the file article count.
        Returns
        -------
        int
            The total number of articles from the file
        """
        return self.c_file.getCountArticles()

    @property
    def namespaces(self) -> str:
        """Get the namespaces.

        Returns
        -------
        str
            A string containing all namespaces in the file

        """
        return self.c_file.getNamespaces().decode("UTF-8", "strict")

    def get_namespaces_count(self, str ns):
        """Get article count from a namespaces.
        Returns
        -------
        int
            The total number of articles from the namespace
        """
        return self.c_file.getNamespaceCount(ord(ns[0]))

    def suggest(self, query, start=0, end=10):
        """Get an iterator of the full urls of suggested articles in the file from a title query.
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
        iterator
            An interator with the urls of suggested articles starting from start position
        """
        cdef unique_ptr[wrapper.Search] search = self.c_file.suggestions(query.encode('UTF-8'),start, end)
        cdef wrapper.search_iterator it = dereference(search).begin()

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def search(self, query, start=0, end=10):
        """Get an iterator of the full urls of articles in the file from a search query.
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
        iterator
            An iterator with the urls of articles matching the search query starting from start position
        """

        cdef unique_ptr[wrapper.Search] search = self.c_file.search(query.encode('UTF-8'),start, end)
        cdef wrapper.search_iterator it = dereference(search).begin()

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def get_search_results_count(self, query):
        """Get search results counts for a query.
        Parameters
        ----------
        query : str
            Query string
        Returns
        -------
        int
            Number of search results
        """
        cdef unique_ptr[wrapper.Search] search = self.c_file.search(query.encode('UTF-8'),0, 1)
        return dereference(search).get_matches_estimated()

    def get_suggestions_results_count(self, query):
        """Get suggestions results counts for a query.
        Parameters
        ----------
        query : str
            Query string
        Returns
        -------
        int
            Number of article suggestions
        """
        cdef unique_ptr[wrapper.Search] search = self.c_file.suggestions(query.encode('UTF-8'),0 , 1)
        return dereference(search).get_matches_estimated()

    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename}"
