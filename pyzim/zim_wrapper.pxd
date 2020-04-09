from libcpp.string cimport string
from libc.stdint cimport uint32_t, uint64_t
from libcpp cimport bool
from libcpp.memory cimport shared_ptr
from libcpp.vector cimport vector



cdef extern from "zim/zim.h" namespace "zim":
    ctypedef uint32_t size_type
    ctypedef uint64_t offset_type

cdef extern from "zim/blob.h" namespace "zim":
    cdef cppclass Blob:
        char* data() except +
        char* end() except +
        int size() except +

cdef extern from "zim/article.h" namespace "zim":
    cdef cppclass Article:
        Article() except +

        string getTitle() except +
        string getUrl() except +
        string getLongUrl() except +
        string getMimeType() except +
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

cdef extern from "zim/file.h" namespace "zim":
    cdef cppclass File:
        File() except +
        File(string filename) except +

        Article getArticle(size_type idx) except +
        Article getArticle(char ns, string url) except +
        Article getArticleByUrl(string url) except +

        Fileheader getFileheader() except +

        size_type getCountArticles() except +
        size_type getNamespaceCount(char ns) except +

        string getNamespaces() except +
        string getChecksum() except +
        string getFilename() except +



cdef extern from "zim/writer/url.h" namespace "zim::writer":
    cdef cppclass Url:
        string getLongUrl() except +


cdef extern from "wrappers.cpp":
    cdef cppclass ZimArticle:
        ZimArticle(const Article article) except +
        ZimArticle(char ns,
                        string url,
                        string title,
                        string mimeType,
                        string redirectAid,
                        bool _shouldIndex,
                        string content) except +
        string getTitle() except +
        const Blob getData() except +
        string getMimeType() except +
        bool isRedirect() except +
        Url getUrl() except +
        Url getRedirectUrl() except +
        char ns
        string url
        string title
        string mimeType
        string redirectUrl
        string content

    cdef cppclass ZimSearch:
        ZimSearch(File *f) except +
        vector[string] suggest(string) except +
        vector[string] search(string) except +

    cdef cppclass ZimCreator:
        @staticmethod
        ZimCreator *create(string fileName, string mainPage, string fullTextIndexLanguage, int minChunkSize) except +
        void addArticle(shared_ptr[ZimArticle] article) except +
        void finalize() except +

cdef extern from "zim/writer/creator.h" namespace "zim::writer":
    cdef cppclass Creator:
        Creator(bool verbose) except +
        void startZimCreation(string filename) except +
        void addArticle(shared_ptr[ZimArticle] article) except +
        void setIndexing(bool indexing, string language) except +
        void setMinChunkSize(offset_type s) except +
        void finishZimCreation() except +