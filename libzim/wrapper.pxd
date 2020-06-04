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
        ZimCreatorWrapper *create(string fileName, string mainPage, string fullTextIndexLanguage, int minChunkSize) nogil except +
        void addArticle(shared_ptr[ZimArticleWrapper] article) nogil except +
        void finalize() nogil except +
        Url getMainUrl() except +
        void setMainUrl(string) except +


cdef extern from "zim/article.h" namespace "zim":
    cdef cppclass Article:
        Article() except +

        string getTitle() except +
        string getUrl() except +
        string getLongUrl() except +
        string getMimeType() except +
        char getNamespace() except +
        bint good() except +

        const Blob getData(size_type offset) except +

        bint isRedirect() except +
        bint isLinktarget() except +
        bint isDeleted() except +

        Article getRedirectArticle() except +


cdef extern from "zim/fileheader.h" namespace "zim":
    cdef cppclass Fileheader:
        bint hasMainPage() except +
        size_type getMainPage() except +


cdef extern from "zim/search_iterator.h" namespace "zim":
    cdef cppclass search_iterator:
        search_iterator()
        search_iterator operator++()
        bint operator==(search_iterator)
        bint operator!=(search_iterator)
        string get_url()
        string get_title()


cdef extern from "zim/search.h" namespace "zim":
    cdef cppclass Search:
        Search(const File* zimfile)
        Search(vector[const File] zimfiles)
        search_iterator begin()
        search_iterator end()
        int get_matches_estimated()


cdef extern from "zim/file.h" namespace "zim":
    cdef cppclass File:
        File() except +
        File(string filename) except +

        Article getArticle(size_type idx) except +
        Article getArticle(char ns, string url) except +
        Article getArticleByUrl(string url) except +

        string getMetadata(string name) except +

        Fileheader getFileheader() except +

        size_type getCountArticles() except +
        size_type getNamespaceCount(char ns) except +

        string getNamespaces() except +
        string getChecksum() except +
        string getFilename() except +

        unique_ptr[Search] search(const string query, int start, int end); 
        unique_ptr[Search] suggestions(const string query, int start, int end);
