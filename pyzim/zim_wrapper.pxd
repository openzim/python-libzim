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
        char* data()
        char* end()
        int size()

cdef extern from "zim/article.h" namespace "zim":
    cdef cppclass Article:
        Article() except +

        string getTitle()
        string getUrl()
        string getLongUrl()
        string getMimeType()
        bint good()

        const Blob getData(size_type offset)

        bint isRedirect()
        bint isLinktarget()
        bint isDeleted()

        Article getRedirectArticle()


cdef extern from "zim/fileheader.h" namespace "zim":
    cdef cppclass Fileheader:
        bint hasMainPage()
        size_type getMainPage()

cdef extern from "zim/file.h" namespace "zim":
    cdef cppclass File:
        File() except +
        File(string filename) except +

        Article getArticle(size_type idx)
        Article getArticle(char ns, string url)
        Article getArticleByUrl(string url)

        Fileheader getFileheader()

        size_type getCountArticles()
        size_type getNamespaceCount(char ns)

        string getNamespaces()
        string getChecksum()
        string getFilename()



cdef extern from "zim/writer/url.h" namespace "zim::writer":
    cdef cppclass Url:
        string getLongUrl()


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
        string getTitle()
        const Blob getData()
        string getMimeType()
        bool isRedirect()
        Url getUrl()
        Url getRedirectUrl()
        char ns
        string url
        string title
        string mimeType
        string redirectUrl
        string content

    cdef cppclass ZimSearch:
        ZimSearch(File *f) except +
        vector[string] suggest(string)
        vector[string] search(string)

    cdef cppclass ZimCreator:
        @staticmethod
        ZimCreator *create(string fileName, string mainPage, string fullTextIndexLanguage, int minChunkSize)
        void addArticle(shared_ptr[ZimArticle] article)
        void finalise()

cdef extern from "zim/writer/creator.h" namespace "zim::writer":
    cdef cppclass Creator:
        Creator(bool verbose) except +
        void startZimCreation(string filename)
        void addArticle(shared_ptr[ZimArticle] article)
        void setIndexing(bool indexing, string language)
        void setMinChunkSize(offset_type s)
        void finishZimCreation()