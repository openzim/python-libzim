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

from cpython.ref cimport PyObject

from libc.stdint cimport uint32_t, uint64_t
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, unique_ptr
from libcpp.string cimport string
from libcpp.vector cimport vector


cdef extern from "zim/zim.h" namespace "zim":
    ctypedef uint64_t size_type
    ctypedef uint64_t offset_type
    ctypedef uint32_t entry_index_type
    ctypedef enum CompressionType:
        zimcompDefault
        zimcompNone
        zimcompZip
        zimcompBzip2
        zimcompLzma
        zimcompZstd


cdef extern from "zim/blob.h" namespace "zim":
    cdef cppclass Blob:
        Blob() except +
        Blob(const char* data, uint64_t size) except +
        const char* data() except +
        const char* end() except +
        uint64_t size() except +


cdef extern from "zim/writer/url.h" namespace "zim::writer":
    cdef cppclass Url:
        string getLongUrl() except +


cdef extern from "zim/writer/article.h" namespace "zim::writer":
    cdef cppclass WriterArticle:
        pass

cdef extern from "lib.h":
    cdef cppclass ZimArticleWrapper(WriterArticle):
        ZimArticleWrapper(PyObject *obj) except +
        const string getTitle() except +
        const Url getUrl() except +
        const string getTitle() except +
        const bool isRedirect() except +
        const string getMimeType() except +
        const string getFilename() except +
        const bool shouldCompress() except +
        const bool shouldIndex() except +
        const Url getRedirectUrl() except +
        const Blob getData() except +

    cdef cppclass ZimCreatorWrapper:
        @staticmethod
        ZimCreatorWrapper *create(string fileName, string mainPage, string fullTextIndexLanguage, CompressionType compression, int minChunkSize) nogil except +
        void addArticle(shared_ptr[ZimArticleWrapper] article) nogil except +
        void finalize() nogil except +
        Url getMainUrl() except +
        void setMainUrl(string) except +




cdef extern from "lib.h":
    cdef cppclass ZimEntry:
        string getTitle()
        string getPath() except +

        bint isRedirect()
        ZimItem* getItem(bint follow) except +
        ZimItem* getRedirect() except +
        ZimEntry* getRedirectEntry() except +


cdef extern from "lib.h":
    cdef cppclass ZimItem:
        ZimItem __enter__()
        string getTitle() except +
        string getPath() except +
        string getMimetype() except +

        const Blob getData(offset_type offset) except +
        const Blob getData(offset_type offset, size_type size) except +
        size_type  getSize() except +


cdef extern from "zim/search_iterator.h" namespace "zim":
    cdef cppclass search_iterator:
        search_iterator()
        search_iterator operator++()
        bint operator==(search_iterator)
        bint operator!=(search_iterator)
        string get_url()
        string get_title()


cdef extern from "lib.h":
    cdef cppclass ZimSearch:
        ZimSearch()
        ZimSearch(const ZimArchive zimfile)
        ZimSearch(vector[const ZimArchive] zimfiles)
        void set_suggestion_mode(bint suggestion)
        void set_query(string query)
        void set_range(int, int)
        search_iterator begin()
        search_iterator end()
        int get_matches_estimated()


cdef extern from "lib.h":
    cdef cppclass ZimArchive:
        ZimArchive(string filename) except +

        ZimEntry* getEntryByPath(string path) except +
        ZimEntry* getEntryByPath(entry_index_type idx) except +
        ZimEntry* getEntryByTitle(string title) except +

        string getMetadata(string name) except +
        vector[string] getMetadataKeys() except +

        ZimEntry* getMainEntry() except +
        size_type getEntryCount() except +

        string getChecksum() except +
        string getFilename() except +
