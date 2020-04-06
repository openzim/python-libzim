from libcpp.string cimport string
from libc.stdint cimport uint32_t, uint64_t
from libcpp cimport bool
from libcpp.memory cimport shared_ptr
from libcpp.vector cimport vector

from cpython.ref cimport PyObject

cdef extern from "zim/blob.h" namespace "zim":
    cdef cppclass Blob:
        Blob()
        Blob(const char* data, uint64_t size)
        char* data()
        char* end()
        uint64_t size()

cdef extern from "zim/writer/url.h" namespace "zim::writer":
    cdef cppclass Url:
        string getLongUrl()


cdef extern from "zim/writer/article.h" namespace "zim::writer": 
    cdef cppclass Article:
        const string getTitle()


cdef extern from "lib.h": 
    cdef cppclass ZimArticleWrapper(Article):
        ZimArticleWrapper(PyObject *obj) except +
        const Url getUrl()
        const string getTitle()
        const bool isRedirect()
        const string getMimeType()
        const string getFilename()
        const bool shouldCompress()
        const bool shouldIndex()
        const Url getRedirectUrl()
        const Blob getData()
    
    cdef cppclass ZimCreatorWrapper:
        @staticmethod
        ZimCreatorWrapper *create(string fileName, string mainPage, string fullTextIndexLanguage, int minChunkSize)
        void addArticle(shared_ptr[ZimArticleWrapper] article)
        void finalise()
