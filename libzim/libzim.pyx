cimport libzim
cimport cpython.ref as cpy_ref
from cython.operator import dereference

from libc.stdint cimport uint32_t, uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared

import datetime

from collections import defaultdict

#########################
#       ZimBlob         #
#########################

cdef class ZimBlob:
    cdef Blob* c_blob

    def __init__(self, content):

        if isinstance(content, str):
            ref_content = content.encode('UTF-8')
        else:
            ref_content = content

        self.c_blob = new Blob(<char *> ref_content, len(ref_content))

    def __dealloc__(self):
        if self.c_blob != NULL:
            del self.c_blob


#########################
#       ZimArticle      #
#########################

cdef class ZimArticle:
    cdef ZimArticleWrapper* c_article

    def __init__(self):
        self.c_article = new ZimArticleWrapper(<cpy_ref.PyObject*>self)
    
    def get_url(self):
        raise NotImplementedError

    def get_title(self):
        raise NotImplementedError
    
    def is_redirect(self):
        raise NotImplementedError

    def get_mime_type(self):
        raise NotImplementedError

    def get_filename(self):
        raise NotImplementedError

    def should_compress(self):
        raise NotImplementedError

    def should_index(self):
        raise NotImplementedError

    def redirect_url(self):
        raise NotImplementedError

    def get_data(self):
        raise NotImplementedError

    @property
    def mimetype(self):
        return self.c_article.getMimeType().decode('UTF-8')
    
    @property
    def content(self):
        blob = self.c_article.getData()
        content =  blob.data()[:blob.size()]
        try:
            return content.decode('UTF-8')
        except UnicodeDecodeError:
            return content

    # This changes with implementation
    @property
    def can_write(self):
        raise NotImplementedError



#------- ZimArticle pure virtual methods --------
cdef public api:
    string string_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a string"""
        cdef ZimArticle art = <ZimArticle>(ptr)
        try:
            func = getattr(art, method.decode('UTF-8'))
        except AttributeError:
            error[0] = 1
            raise 
        else:
            error[0] = 0
            value = func()
            return value.encode('UTF-8')
    
    Blob blob_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a Blob"""
        cdef ZimArticle art = <ZimArticle>(ptr)
        cdef ZimBlob blob = ZimBlob(b'\x00')
        try:
            func = getattr(art, method.decode('UTF-8'))
        except AttributeError:
            error[0] = 1
            raise 
        else:
            error[0] = 0
            blob = func()
            return dereference(blob.c_blob) 
    
    bool bool_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a bool"""

        cdef ZimArticle art = <ZimArticle>(ptr)
        try:
            func = getattr(art, method.decode('UTF-8'))
        except AttributeError:
            error[0] = 1
            raise 
        else:
            error[0] = 0
            return func()

    uint64_t int_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning an int"""

        cdef ZimArticle art = <ZimArticle>(ptr)
        try:
            func = getattr(art, method.decode('UTF-8'))
        except AttributeError:
            error[0] = 1
            raise 
        else:
            error[0] = 0
            return <uint64_t> func()


#########################
#       ZimCreator      #
#########################

#TODO Should we declare an article for metadata or left to the user managing ?


cdef class ZimCreator:
    """ 
    A class to represent a Zim Creator. 
    
    Attributes
    ----------
    *c_creator : zim.ZimCreator
        a pointer to the C++ Creator object
    _finalized : bool
        flag if the creator was finalized
    _filename : str
        Zim file path
    _main_page : str
        Zim file main page
    _index_language : str
        Zim file Index language 
    _min_chunk_size : str
        Zim file minimum chunk size
    """
    
    cdef ZimCreatorWrapper *c_creator
    cdef bool _finalized
    cdef object _filename
    cdef object _main_page
    cdef object _index_language
    cdef object _min_chunk_size
    cdef object _article_counter

    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        """Constructs a ZimCreator from parameters.
        Parameters
        ----------
        filename : str
            Zim file path
        main_page : str
            Zim file main_page
        index_language : str
            Zim file index language (default eng)
        min_chunk_size : int
            Minimum chunk size (default 2048)
        """

        self.c_creator = ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self._finalized = False
        self._filename = filename
        self._main_page = self.c_creator.getMainUrl().getLongUrl().decode("UTF-8", "strict")
        self._index_language = index_language
        self._min_chunk_size = min_chunk_size
        
        self._article_counter = defaultdict(int)

    
    @property
    def filename(self):
        """Get the filename of the ZimCreator object"""
        return self._filename

    @property
    def main_page(self):
        """Get the main page of the ZimCreator object"""
        return self.c_creator.getMainUrl().getLongUrl().decode("UTF-8", "strict")[2:]
    
    @main_page.setter
    def main_page(self,new_url):
        """Set the main page of the ZimCreator object"""
        # Check if url longformat is used
        if new_url[1] == '/':
            raise ValueError("Url should not include a namespace")

        self.c_creator.setMainUrl(new_url.encode('UTF-8'))

    @property
    def index_language(self):
        """Get the index language of the ZimCreator object"""
        return self._index_language

    @property
    def min_chunk_size(self):
        """Get the minimum chunk size of the ZimCreator object"""
        return self._min_chunk_size

    def _update_article_counter(self, ZimArticle article):
        # default dict update
        self._article_counter[article.mimetype] += 1

    def add_article(self, ZimArticle article not None):
        """Add a ZimArticle to the Creator object.
        
        Parameters
        ----------
        article : ZimArticle
            The article to add to the file
        Raises
        ------
            RuntimeError
                If the ZimArticle provided is not ready for writing
            RuntimeError
                If the ZimCreator was already finalized
        """
        if self._finalized:
            raise RuntimeError("ZimCreator already finalized")

        if not article.can_write:
            raise RuntimeError("Article is not good for writing")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object (dereference internal c_article)
        cdef shared_ptr[ZimArticleWrapper] art = make_shared[ZimArticleWrapper](dereference(article.c_article));
        try:
            self.c_creator.addArticle(art)
        except:
            raise
        else:
            if not article.is_redirect:
                self._update_article_counter(article)

    def finalize(self):
        """finalize and write added articles to the file.
        
        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """

        if not self._finalized:
            self.c_creator.finalize()
            self._finalized = True
        else:
            raise RuntimeError("ZimCreator already finalized")
    
    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename})"