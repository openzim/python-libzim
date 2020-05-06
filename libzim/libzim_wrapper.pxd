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
from libcpp.memory cimport shared_ptr
from libcpp.string cimport string
from libcpp.vector cimport vector


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
    cdef cppclass Article:
        const string getTitle() except +


cdef extern from "lib.h":
    cdef cppclass ZimArticleWrapper(Article):
        ZimArticleWrapper(PyObject *obj) except +
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
