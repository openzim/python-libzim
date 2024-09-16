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
from libcpp.pair cimport pair
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
        Zstd "zim::Compression::Zstd"


cdef extern from "zim/writer/item.h" namespace "zim::writer":
    cdef cppclass WriterItem "zim::writer::Item":
        pass
    ctypedef enum HintKeys:
        COMPRESS
        FRONT_ARTICLE

    cdef cppclass IndexData:
        pass

cdef extern from "zim/writer/item.h" namespace "zim::writer::IndexData":
    cppclass GeoPosition:
        GeoPosition()
        GeoPosition(bool, double, double)

cdef extern from "zim/writer/contentProvider.h" namespace "zim::writer":
    cdef cppclass ContentProvider:
        pass


cdef extern from "zim/writer/creator.h" namespace "zim::writer":
    cdef cppclass ZimCreator "zim::writer::Creator":
        void config_verbose(bint verbose)
        void config_compression(Compression compression)
        void config_cluster_size(int size)
        void config_indexing(bint indexing, string language)
        void config_nb_workers(int nbWorkers)
        void start_zim_creation(string filepath) nogil except +;
        void add_item(shared_ptr[WriterItem] item) nogil except +
        void add_metadata(string name, string content, string mimetype) nogil except +
        void add_redirection(string path, string title, string targetpath, map[HintKeys, uint64_t] hints) nogil except +
        void add_alias(string path, string title, string targetpath, map[HintKeys, uint64_t] hints) except + nogil
        void finish_zim_creation() nogil except +
        void set_main_path(string mainPath)
        void add_illustration(unsigned int size, string content) nogil except +

cdef extern from "zim/search.h" namespace "zim":
    cdef cppclass Query:
        Query()
        Query& set_query(string query)
        Query& set_georange(float latitude, float longitude, float distance)


cdef extern from "zim/search_iterator.h" namespace "zim":
    cdef cppclass SearchIterator:
        SearchIterator()
        SearchIterator operator++()
        bint operator==(SearchIterator)
        bint operator!=(SearchIterator)
        string get_path()
        string get_title()


# Import the python wrappers (ObjWrapper) from libwrapper.
# The only thing we need to know here is how to create the wrappers.
# Other (cpp) methods must exists (to be called from cpp side),
# but we don't care about them as we will not call them in python side.
cdef extern from "libwrapper.h":
    cdef cppclass ContentProviderWrapper(ContentProvider):
        ContentProviderWrapper(PyObject* obj) except +
    cdef cppclass WriterItemWrapper:
        WriterItemWrapper(PyObject* obj) except +
    cdef cppclass IndexDataWrapper(IndexData):
        IndexDataWrapper(PyObject* obj) except +

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
        string get_title()
        string get_path() except +

        bint is_redirect()
        Item get_item(bint follow) except +
        Item get_redirect() except +
        Entry get-redirect_entry() except +

        int get_index() except +

    cdef cppclass Item:
        string get_title() except +
        string get_path() except +
        string get_mimetype() except +

        Blob get_data(offset_type offset) except +
        Blob get_data(offset_type offset, size_type size) except +
        size_type  get_size() except +

        int get_index() except +

    cdef cppclass Archive:
        Archive() except +
        Archive(string filename) except +

        uint64_t get_filesize() except +

        Entry get_entry_by_path(string path) except +
        Entry get_entry_by_path(entry_index_type idx) except +
        Entry get_entry_by_title(string title) except +

        string get_metadata(string name) except +
        Item get_metadata_item(string name) except +
        vector[string] get_metadata_keys() except +

        Entry get_main_entry() except +
        Item get_illustration_item() except +
        Item get_illustration_item(int size) except +
        size_type get_entry_count() except +
        size_type get_all_entry_count() except +
        size_type get_article_count() except +
        size_type get_media_count() except +

        string get_checksum() except +
        string get_filename() except +
        string get_uuid() except +

        bool hasMainEntry() except +
        bool has_illustration() except +
        bool has_illustration(unsigned int size) except +
        set[unsigned int] get_illustration_sizes() except +
        bool has_entry_by_path(string path) except +
        bool has_entry_by_title(string title) except +
        bool is_multi_part() except +
        bool has_new_namespace_scheme() except +
        bool has_fulltext_index() except +
        bool has_title_index() except +
        bool has_checksum() except +
        bool check() except +

    cdef cppclass Searcher:
        Searcher()
        Searcher(const Archive& archive) except +
        setVerbose(bool verbose)
        Search search(Query query) except +

    cdef cppclass Search:
        int get_estimated_matches() except +
        SearchResultSet get_results(int start, int count) except +

    cdef cppclass SearchResultSet:
        SearchIterator begin()
        SearchIterator end()
        int size()

    cdef cppclass SuggestionItem:
        string get_path()
        string get_title()
        string get_snippet()
        bool has_snippet()

    cdef cppclass SuggestionIterator:
        SuggestionIterator()
        SuggestionIterator operator++()
        bint operator==(SuggestionIterator)
        bint operator!=(SuggestionIterator)
        SuggestionItem get_suggestion_item()
        Entry get_entry()

    cdef cppclass SuggestionSearcher:
        SuggestionSearcher()
        SuggestionSearcher(const Archive& archive) except +
        setVerbose(bool verbose)
        SuggestionSearch suggest(string query) except +

    cdef cppclass SuggestionSearch:
        int get_estimated_matches() except +
        SuggestionResultSet get_results(int start, int count) except +

    cdef cppclass SuggestionResultSet:
        SuggestionIterator begin()
        SuggestionIterator end()
        int size()

cdef extern from "zim/version.h" namespace "zim":
    cdef vector[pair[string, string]] getVersions()
