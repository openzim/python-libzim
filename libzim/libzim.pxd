from libcpp.string cimport string
from libc.stdint cimport uint32_t, uint64_t
from libcpp cimport bool
from libcpp.memory cimport shared_ptr
from libcpp.vector cimport vector

from cpython.ref cimport PyObject

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
