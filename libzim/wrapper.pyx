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
from uuid import UUID
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
        *blob : Blob
            Pointer to a C++ (zim::) blob object
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


#------- pure virtual methods --------

cdef public api:
    string string_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a string"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            ret_str = func()
            return ret_str.encode('UTF-8')
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')
        return b""

    wrapper.Blob blob_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a Blob"""
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

    wrapper.ContentProvider* contentprovider_cy_call_fct(object obj, string method, string *error) with gil:
        try:
            func = getattr(obj, method.decode('UTF-8'))
            contentProvider = func()
            if not contentProvider:
                raise RuntimeError("ContentProvider is None")
            return new ContentProviderWrapper(<PyObject*>contentProvider)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return NULL

    bool bool_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a bool"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            return func()
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')
        return False

    uint64_t int_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning an int"""
        try:
            func = getattr(obj, method.decode('UTF-8'))
            return <uint64_t>func()
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return 0


class Compression(enum.Enum):
    """ Compression algorithms available to create ZIM files """
    none = wrapper.CompressionType.zimcompNone
    lzma = wrapper.CompressionType.zimcompLzma
    zstd = wrapper.CompressionType.zimcompZstd


cdef class Creator:
    """ Zim Creator

        Attributes
        ----------
        *c_creator : zim.ZimCreator
            a pointer to the C++ Creator object
        _filename: pathlib.Path
            path to create the ZIM file at
        _started : bool
            flag if the creator has started """

    cdef wrapper.ZimCreator c_creator
    cdef object _filename
    cdef object _started

    def __cinit__(self, object filename: pathlib.Path):
        """ Constructs a File from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file """

        self._filename = pathlib.Path(filename)

    def configVerbose(self, bool verbose) -> Creator:
        if self._started:
            raise RuntimeError("ZimCreator started")
        self.c_creator.configVerbose(verbose)
        return self

    def configCompression(self, comptype: Compression) -> Creator:
        if self._started:
            raise RuntimeError("ZimCreator started")
        self.c_creator.configCompression(comptype.value)
        return self

    def configMinClusterSize(self, int size) -> Creator:
        if self._started:
            raise RuntimeError("ZimCreator started")
        self.c_creator.configMinClusterSize(size)
        return self

    def configIndexing(self, bool indexing, str language) -> Creator:
        if self._started:
            raise RuntimeError("ZimCreator started")
        self.c_creator.configIndexing(indexing, language.encode('utf8'))
        return self

    def configNbWorkers(self, int nbWorkers) -> Creator:
        if self._started:
            raise RuntimeError("ZimCreator started")
        self.c_creator.configNbWorkers(nbWorkers)
        return self

    def setMainPath(self, str mainPath):
        self.c_creator.setMainPath(mainPath.encode('utf8'))

    def setFaviconPath(self, str faviconPath):
        self.c_creator.setFaviconPath(faviconPath.encode('utf8'))

#    def setUuid(self, uuid) -> Creator:
#        self.c_creator.setUuid(uuid)

    def add_item(self, WriterItem not None):
        """ Add an item to the Creator object.

            Parameters
            ----------
            item : WriterItem
                The item to add to the file
            Raises
            ------
                RuntimeError
                    If the ZimCreator was already finalized """
        if not self._started:
            raise RuntimeError("ZimCreator not started")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object
        cdef shared_ptr[wrapper.WriterItem] item = shared_ptr[wrapper.WriterItem](
            new wrapper.WriterItemWrapper(<PyObject*>WriterItem));
        with nogil:
            self.c_creator.addItem(item)

    def add_metadata(self, str name, bytes content, str mimetype = "text/plain"):
        if not self._started:
            raise RuntimeError("ZimCreator not started")

        cdef string _name = name.encode('utf8')
        cdef string _content = content
        cdef string _mimetype = mimetype.encode('utf8')
        with nogil:
            self.c_creator.addMetadata(_name, _content, _mimetype)

    def add_redirection(self, str path, str title, str targetPath):
        if not self._started:
            raise RuntimeError("ZimCreator not started")

        cdef string _path = path.encode('utf8')
        cdef string _title = title.encode('utf8')
        cdef string _targetPath = targetPath.encode('utf8')
        with nogil:
            self.c_creator.addRedirection(_path, _title, _targetPath)

    def __enter__(self):
        cdef string _path = str(self._filename).encode('utf8')
        with nogil:
            self.c_creator.startZimCreation(_path)
        self._started = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if True or exc_type is None:
            with nogil:
                self.c_creator.finishZimCreation()
        self._started = False

    @property
    def filename(self):
        return self._filename

########################
#         Entry        #
########################

cdef class Entry:
    """ Entry in a Zim archive

        Attributes
        ----------
        *c_entry : Entry (zim::)
            a pointer to the C++ entry object """
    cdef wrapper.ZimEntry* c_entry

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_entry(wrapper.ZimEntry* ent):
        """ Creates a python Entry from a C++ Entry (zim::) -> Entry

            Parameters
            ----------
            ent : Entry
                A C++ Entry
            Returns
            ------
            Entry
                Casted entry """
        cdef Entry entry = Entry()
        entry.c_entry = ent
        return entry

    def __dealloc__(self):
        if self.c_entry != NULL:
            del self.c_entry

    @property
    def title(self) -> str:
        return self.c_entry.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        return self.c_entry.getPath().decode("UTF-8", "strict")

    @property
    def is_redirect(self) -> bool:
        """ Whether entry is a redirect -> bool """
        return self.c_entry.isRedirect()

    def get_redirect_entry(self) -> Entry:
        cdef ZimEntry* entry = self.c_entry.getRedirectEntry()
        return Entry.from_entry(entry)

    def get_item(self) -> Item:
        cdef ZimItem* item = self.c_entry.getItem(True)
        return Item.from_item(item)

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.path}, title={self.title})"

cdef class Item:
    """ Item in a Zim archive

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
            _item : Item
                A C++ Item
            Returns
            ------
            Item
                Casted item """
        cdef Item item = Item()
        item.c_item = _item
        return item

    def __dealloc__(self):
        if self.c_item != NULL:
            del self.c_item

    @property
    def title(self) -> str:
        return self.c_item.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        return self.c_item.getPath().decode("UTF-8", "strict")

    @property
    def content(self) -> memoryview:
        if not self._haveBlob:
            self._blob = ReadingBlob()
            self._blob.__setup(self.c_item.getData(<int> 0))
            self._haveBlob = True
        return memoryview(self._blob)

    @property
    def mimetype(self) -> str:
        return self.c_item.getMimetype().decode('UTF-8')

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.path}, title={self.title})"




#########################
#        Archive        #
#########################

cdef class PyArchive:
    """ Zim Archive Reader

        Attributes
        ----------
        *c_archive : Archive
            a pointer to a C++ Archive object
        _filename : pathlib.Path
            the file name of the Archive Reader object """

    cdef wrapper.ZimArchive* c_archive
    cdef object _filename

    def __cinit__(self, object filename: pathlib.Path):
        """ Constructs an Archive from full zim file path

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
        return self._filename

    @property
    def filesize(self) -> int:
        """ total size of ZIM file (or files if split """
        return self.c_archive.getFilesize()

    def get_entry_by_path(self, path: str) -> Entry:
        """ Entry from a path -> Entry

            Parameters
            ----------
            path : str
                The path of the article
            Returns
            -------
            Entry
                The Entry object
            Raises
            ------
                KeyError
                    If an article with the provided path is not found in the archive """
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
                name/path of the Metadata Entry
            Returns
            -------
            bytes
                Metadata entry's content. Can be of any type. """
        return bytes(self.c_archive.getMetadata(name.encode('UTF-8')))

    def get_entry_by_id(self, entry_id: int) -> Entry:
        cdef wrapper.ZimEntry* entry = self.c_archive.getEntryByPath(<entry_index_type>entry_id)
        return Entry.from_entry(entry)

    @property
    def main_entry(self) -> Entry:
        return Entry.from_entry(self.c_archive.getMainEntry())

    @property
    def favicon_entry(self) -> Entry:
        return Entry.from_entry(self.c_archive.getFaviconEntry())

    @property
    def uuid(self) -> UUID:
        return UUID(self.c_archive.getUuid().hex())

    @property
    def new_namespace_scheme(self) -> bool:
        return self.c_archive.hasNewNamespaceScheme()

    @property
    def has_fulltext_index(self) -> bool:
        return self.c_archive.hasFulltextIndex()

    @property
    def has_title_index(self) -> bool:
        return self.c_archive.hasTitleIndex()

    @property
    def checksum(self) -> str:
        return self.c_archive.getChecksum().decode("UTF-8", "strict")

    @property
    def entry_count(self) -> int:
        return self.c_archive.getEntryCount()

    def suggest(self, query: str, start: int = 0, end: int = 10) -> Generator[str, None, None]:
        """ Paths of suggested entries in the archive from a title query -> Generator[str, None, None]

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
                Path of suggested entry """
        cdef wrapper.ZimSearch search = wrapper.ZimSearch(dereference(self.c_archive))
        search.set_suggestion_mode(True)
        search.set_query(query.encode('UTF-8'))
        search.set_range(start, end)

        cdef wrapper.search_iterator it = search.begin()
        while it != search.end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def search(self, query: str, start: int = 0, end: int = 10) -> Generator[str, None, None]:
        """ Paths of entries in the archive from a search query -> Generator[str, None, None]

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
                Path of entry matching the search query """

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
