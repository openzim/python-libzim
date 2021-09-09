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
from libcpp.map cimport map


cdef extern from "zim/zim.h" namespace "zim":
    ctypedef uint64_t size_type
    ctypedef uint64_t offset_type
    ctypedef uint32_t entry_index_type
    ctypedef enum CompressionType:
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


cdef extern from "zim/writer/item.h" namespace "zim::writer":
    cdef cppclass WriterItem "zim::writer::Item":
        pass
    ctypedef enum HintKeys:
        COMPRESS
        FRONT_ARTICLE

cdef extern from "zim/writer/contentProvider.h" namespace "zim::writer":
    cdef cppclass ContentProvider:
        pass


cdef extern from "zim/writer/creator.h" namespace "zim::writer":
    cdef cppclass ZimCreator "zim::writer::Creator":
        void configVerbose(bint verbose)
        void configCompression(CompressionType comptype)
        void configClusterSize(int size)
        void configIndexing(bint indexing, string language)
        void configNbWorkers(int nbWorkers)
        void startZimCreation(string filepath) nogil except +;
        void addItem(shared_ptr[WriterItem] item) nogil except +
        void addMetadata(string name, string content, string mimetype) nogil except +
        void addRedirection(string path, string title, string targetpath, map[HintKeys, uint64_t] hints) nogil except +
        void finishZimCreation() nogil except +
        void setMainPath(string mainPath)
        void addIllustration(unsigned int size, string content)

cdef extern from "lib.h":
    # The only thing we need to know here is how to create the Wrapper.
    # Other (cpp) methods must exists and they will be called,
    # but we don't care about them here.
    cdef cppclass ContentProviderWrapper(ContentProvider):
        ContentProviderWrapper(PyObject* obj) except +
    cdef cppclass WriterItemWrapper:
        WriterItemWrapper(PyObject* obj) except +


# Import the cpp wrappers.
cdef extern from "libwrapper.h":
    cdef cppclass WEntry:
        string getTitle()
        string getPath() except +

        bint isRedirect()
        WItem getItem(bint follow) except +
        WItem getRedirect() except +
        WEntry getRedirectEntry() except +

        int getIndex() except +

    cdef cppclass WItem:
        string getTitle() except +
        string getPath() except +
        string getMimetype() except +

        const Blob getData(offset_type offset) except +
        const Blob getData(offset_type offset, size_type size) except +
        size_type  getSize() except +

        int getIndex() except +

    cdef cppclass WArchive:
        WArchive() except +
        WArchive(string filename) except +

        int getFilesize() except +

        WEntry getEntryByPath(string path) except +
        WEntry getEntryByPath(entry_index_type idx) except +
        WEntry getEntryByTitle(string title) except +

        string getMetadata(string name) except +
        vector[string] getMetadataKeys() except +

        WEntry getMainEntry() except +
        WItem getIllustrationItem() except +
        WItem getIllustrationItem(int size) except +
        size_type getEntryCount() except +
        size_type getAllEntryCount() except +
        size_type getArticleCount() except +

        string getChecksum() except +
        string getFilename() except +
        string getUuid() except +

        bool hasMainEntry() except +
        bool hasIllustration() except +
        bool hasIllustration(unsigned int size) except +
        # set[unsigned int] getIllustrationSizes() except +
        bool hasEntryByPath(string path) except +
        bool hasEntryByTitle(string title) except +
        bool is_multiPart() except +
        bool hasNewNamespaceScheme() except +
        bool hasFulltextIndex() except +
        bool hasTitleIndex() except +
        bool hasChecksum() except +
        bool check() except +

cdef extern from "zim/search_iterator.h" namespace "zim":
    cdef cppclass SearchIterator:
        SearchIterator()
        SearchIterator operator++()
        bint operator==(search_iterator)
        bint operator!=(search_iterator)
        string getPath()
        string getTitle()
