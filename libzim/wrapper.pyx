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

import enum
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

    def size(self):
        return self.c_blob.size()

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


class Compression(enum.Enum):
    """ Compression algorithms available to create ZIM files """
    none = wrapper.CompressionType.zimcompNone
    zip = wrapper.CompressionType.zimcompZip
    lzma = wrapper.CompressionType.zimcompLzma
    zstd = wrapper.CompressionType.zimcompZstd


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

    def __cinit__(self, str filename: str, str main_page: str = "", str index_language: str = "eng", compression = Compression.lzma, int min_chunk_size = 2048):
        """ Constructs a Zim Creator from parameters.

            Parameters
            ----------
            filename : str
                Zim file path
            main_page : str
                Zim file main page (without namespace, must be in A/)
            index_language : str
                Zim file index language (default eng)
            compression: Compression
                Compression algorithm to use
            min_chunk_size : int
                Minimum chunk size (default 2048) """
        self.c_creator = wrapper.ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), compression.value, min_chunk_size)
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

cdef class Entry:
    """ Entry in a Zim file

        Attributes
        ----------
        *c_entry : Entry (zim::)
            a pointer to the C++ entry object """
    cdef wrapper.ZimEntry* c_entry

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_entry(wrapper.ZimEntry* ent):
        """ Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            art : Article
                A C++ Article read with File
            Returns
            ------
            ReadArticle
                Casted article """
        cdef Entry entry = Entry()
        entry.c_entry = ent
        return entry

    def __dealloc__(self):
        if self.c_entry != NULL:
            del self.c_entry

    @property
    def title(self) -> str:
        """ Article's title -> str """
        return self.c_entry.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        """ Article's url without namespace -> str """
        return self.c_entry.getPath().decode("UTF-8", "strict")

    @property
    def is_redirect(self) -> bool:
        """ Whether article is a redirect -> bool """
        return self.c_entry.isRedirect()

    def get_redirect_entry(self) -> Entry:
        cdef ZimEntry* entry = self.c_entry.getRedirectEntry()
        return Entry.from_entry(entry)

    def get_item(self) -> Item:
        cdef ZimItem* item = self.c_entry.getItem(True)
        return Item.from_item(item)

cdef class Item:
    """ Item in a Zim file

        Attributes
        ----------
        *c_entry : Entry (zim::)
            a pointer to the C++ entry object """
    cdef wrapper.ZimItem* c_item
    cdef ReadingBlob _blob
    cdef bool _haveBlob

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_item(wrapper.ZimItem* _item):
        """ Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            art : Article
                A C++ Article read with File
            Returns
            ------
            ReadArticle
                Casted article """
        cdef Item item = Item()
        item.c_item = _item
        return item

    def __dealloc__(self):
        if self.c_item != NULL:
            del self.c_item

    @property
    def title(self) -> str:
        """ Article's title -> str """
        return self.c_item.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        """ Article's url without namespace -> str """
        return self.c_item.getPath().decode("UTF-8", "strict")

    @property
    def content(self) -> memoryview:
        """ Article's content -> memoryview """
        if not self._haveBlob:
            self._blob = ReadingBlob()
            self._blob.__setup(self.c_item.getData(<int> 0))
            self._haveBlob = True
        return memoryview(self._blob)

    @property
    def mimetype(self) -> str:
        """ Article's mimetype -> str """
        return self.c_item.getMimetype().decode('UTF-8')

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.longurl}, title={self.title})"




#########################
#        File           #
#########################

cdef class PyArchive:
    """ Zim File Reader

        Attributes
        ----------
        *c_archive : Archive
            a pointer to a C++ Archive object
        _filename : pathlib.Path
            the file name of the File Reader object """

    cdef wrapper.ZimArchive* c_archive
    cdef object _filename

    def __cinit__(self, object filename: pathlib.Path):
        """ Constructs a File from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file """

        self.c_archive = new wrapper.ZimArchive(str(filename).encode('UTF-8'))
        self._filename = pathlib.Path(self.c_archive.getFilename().decode("UTF-8", "strict"))

    def __dealloc__(self):
        if self.c_archive != NULL:
            del self.c_archive

    @property
    def filename(self) -> pathlib.Path:
        """ Filename of the File object -> pathlib.Path """
        return self._filename

    def get_entry_by_path(self, path: str) -> Entry:
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
        cdef wrapper.ZimEntry* entry
        try:
            entry = self.c_archive.getEntryByPath(<string>path.encode('UTF-8'))
        except RuntimeError as e:
            raise KeyError(str(e))
        return Entry.from_entry(entry)

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
        return bytes(self.c_archive.getMetadata(name.encode('UTF-8')))

    def get_entry_by_id(self, entry_id: int) -> Entry:
        cdef wrapper.ZimEntry* entry = self.c_archive.getEntryByPath(<entry_index_type>entry_id)
        return Entry.from_entry(entry)

    @property
    def main_entry(self) -> Entry:
        """ File's main page full url -> str

            Returns
            -------
            str
                The url of the main page, including namespace """
        return Entry.from_entry(self.c_archive.getMainEntry())

    @property
    def checksum(self) -> str:
        """ File's checksum -> str

            Returns
            -------
            str
                The file's checksum """
        return self.c_archive.getChecksum().decode("UTF-8", "strict")

    @property
    def entry_count(self) -> int:
        """ File's articles count -> int

            Returns
            -------
            int
                The total number of articles in the file """
        return self.c_archive.getEntryCount()

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
        cdef wrapper.ZimSearch search = wrapper.ZimSearch(dereference(self.c_archive))
        search.set_suggestion_mode(True)
        search.set_query(query.encode('UTF-8'))
        search.set_range(start, end)

        cdef wrapper.search_iterator it = search.begin()
        while it != search.end():
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

        cdef wrapper.ZimSearch search = wrapper.ZimSearch(dereference(self.c_archive))
        search.set_suggestion_mode(False)
        search.set_query(query.encode('UTF-8'))
        search.set_range(start, end)

        cdef wrapper.search_iterator it = search.begin()
        while it != search.end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def get_estimated_search_results_count(self, query: str) -> int:
        """ Estimated number of search results for a query -> int

            Parameters
            ----------
            query : str
                Query string
            Returns
            -------
            int
                Estimated number of search results """
        cdef wrapper.ZimSearch search = wrapper.ZimSearch(dereference(self.c_archive))
        search.set_suggestion_mode(False)
        search.set_query(query.encode('UTF-8'))
        search.set_range(0, 1)

        return search.get_matches_estimated()

    def get_estimated_suggestions_results_count(self, query: str) -> int:
        """ Estimated number of suggestions for a query -> int

            Parameters
            ----------
            query : str
                Query string
            Returns
            -------
            int
                Estimated number of article suggestions """
        cdef wrapper.ZimSearch search = wrapper.ZimSearch(dereference(self.c_archive))
        search.set_suggestion_mode(True)
        search.set_query(query.encode('UTF-8'))
        search.set_range(0, 1)
 
        return search.get_matches_estimated()

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(filename={self.filename})"
