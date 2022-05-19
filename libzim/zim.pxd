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
from libcpp.map cimport map
from libcpp.memory cimport shared_ptr
from libcpp.set cimport set
from libcpp.string cimport string
from libcpp.vector cimport vector


cdef extern from "zim/zim.h" namespace "zim":
    ctypedef uint64_t size_type
    ctypedef uint64_t offset_type
    ctypedef uint32_t entry_index_type
    cdef enum Compression:
        # We need to declare something here to be syntaxically correct
        # but we don't use those values (even if they are valid).
        None "zim::Compression::None"
        Lzma "zim::Compression::Lzma"
        Zstd "zim::Compression::Zstd"


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
        void configCompression(Compression compression)
        void configClusterSize(int size)
        void configIndexing(bint indexing, string language)
        void configNbWorkers(int nbWorkers)
        void startZimCreation(string filepath) nogil except +;
        void addItem(shared_ptr[WriterItem] item) nogil except +
        void addMetadata(string name, string content, string mimetype) nogil except +
        void addRedirection(string path, string title, string targetpath, map[HintKeys, uint64_t] hints) nogil except +
        void finishZimCreation() nogil except +
        void setMainPath(string mainPath)
        void addIllustration(unsigned int size, string content) nogil except +

cdef extern from "zim/search.h" namespace "zim":
    cdef cppclass Query:
        Query()
        Query& setQuery(string query)
        Query& setGeorange(float latitude, float longitude, float distance)


cdef extern from "zim/search_iterator.h" namespace "zim":
    cdef cppclass SearchIterator:
        SearchIterator()
        SearchIterator operator++()
        bint operator==(SearchIterator)
        bint operator!=(SearchIterator)
        string getPath()
        string getTitle()


# Import the python wrappers (ObjWrapper) from libwrapper.
# The only thing we need to know here is how to create the wrappers.
# Other (cpp) methods must exists (to be called from cpp side),
# but we don't care about them as we will not call them in python side.
cdef extern from "libwrapper.h":
    cdef cppclass ContentProviderWrapper(ContentProvider):
        ContentProviderWrapper(PyObject* obj) except +
    cdef cppclass WriterItemWrapper:
        WriterItemWrapper(PyObject* obj) except +

    Compression comp_from_int(int)


# Import the cpp wrappers.
cdef extern from "libwrapper.h" namespace "wrapper":
    cdef cppclass Blob:
        Blob() except +
        Blob(const char* data, uint64_t size) except +
        const char* data() except +
        const char* end() except +
        uint64_t size() except +

    cdef cppclass Entry:
        string getTitle()
        string getPath() except +

        bint isRedirect()
        Item getItem(bint follow) except +
        Item getRedirect() except +
        Entry getRedirectEntry() except +

        int getIndex() except +

    cdef cppclass Item:
        string getTitle() except +
        string getPath() except +
        string getMimetype() except +

        Blob getData(offset_type offset) except +
        Blob getData(offset_type offset, size_type size) except +
        size_type  getSize() except +

        int getIndex() except +

    cdef cppclass Archive:
        Archive() except +
        Archive(string filename) except +

        uint64_t getFilesize() except +

        Entry getEntryByPath(string path) except +
        Entry getEntryByPath(entry_index_type idx) except +
        Entry getEntryByTitle(string title) except +

        string getMetadata(string name) except +
        Item getMetadataItem(string name) except +
        vector[string] getMetadataKeys() except +

        Entry getMainEntry() except +
        Item getIllustrationItem() except +
        Item getIllustrationItem(int size) except +
        size_type getEntryCount() except +
        size_type getAllEntryCount() except +
        size_type getArticleCount() except +

        string getChecksum() except +
        string getFilename() except +
        string getUuid() except +

        bool hasMainEntry() except +
        bool hasIllustration() except +
        bool hasIllustration(unsigned int size) except +
        set[unsigned int] getIllustrationSizes() except +
        bool hasEntryByPath(string path) except +
        bool hasEntryByTitle(string title) except +
        bool isMultiPart() except +
        bool hasNewNamespaceScheme() except +
        bool hasFulltextIndex() except +
        bool hasTitleIndex() except +
        bool hasChecksum() except +
        bool check() except +

    cdef cppclass Searcher:
        Searcher()
        Searcher(const Archive& archive) except +
        setVerbose(bool verbose)
        Search search(Query query) except +

    cdef cppclass Search:
        int getEstimatedMatches() except +
        SearchResultSet getResults(int start, int count) except +

    cdef cppclass SearchResultSet:
        SearchIterator begin()
        SearchIterator end()
        int size()

    cdef cppclass SuggestionItem:
        string getPath()
        string getTitle()
        string getSnippet()
        bool hasSnippet()

    cdef cppclass SuggestionIterator:
        SuggestionIterator()
        SuggestionIterator operator++()
        bint operator==(SuggestionIterator)
        bint operator!=(SuggestionIterator)
        SuggestionItem getSuggestionItem()
        Entry getEntry()

    cdef cppclass SuggestionSearcher:
        SuggestionSearcher()
        SuggestionSearcher(const Archive& archive) except +
        setVerbose(bool verbose)
        SuggestionSearch suggest(string query) except +

    cdef cppclass SuggestionSearch:
        int getEstimatedMatches() except +
        SuggestionResultSet getResults(int start, int count) except +

    cdef cppclass SuggestionResultSet:
        SuggestionIterator begin()
        SuggestionIterator end()
        int size()
