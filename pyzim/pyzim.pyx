cimport pyzim
cimport cpython.ref as cpy_ref
from cython.operator import dereference

from libc.stdint cimport uint32_t, uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared

import datetime
from collections import defaultdict

#########################
#       ZimArticle      #
#########################

cdef class ZimBlob:
    cdef Blob* c_blob

    def __init__(self, bytes content):
        self.c_blob = new Blob(<char *> content, len(content))

    def __dealloc__(self):
        if self.c_blob != NULL:
            del self.c_blob

cdef class ZimArticle:
    cdef ZimArticleWrapper* c_article

    def __init__(self):
        self.c_article = new ZimArticleWrapper(<cpy_ref.PyObject*>self)
    
    def __dealloc__(self):
        if self.c_article != NULL:
            del self.c_article

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
        return blob.data()[:blob.size()].decode('UTF-8')

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

cdef public api:    
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

class ZimTestArticle(ZimArticle):
    content = '''<!DOCTYPE html> 
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical</title>
                <h1> ñññ Hello, it works ñññ </h1></html>'''

    def __init__(self):
        ZimArticle.__init__(self)

    def is_redirect(self):
        return False

    @property
    def can_write(self):
        return True

    def get_url(self):
        return "A/Monadical_SAS"

    def get_title(self):
        return "Monadical SAS"
    
    def get_mime_type(self):
        return "text/html"
    
    def get_filename(self):
        return ""
    
    def should_compress(self):
        return True

    def should_index(self):
        return True

    def get_data(self):
        return ZimBlob(self.content.encode('UTF-8'))

#########################
#       ZimCreator      #
#########################


cdef class ZimCreator:
    cdef ZimCreatorWrapper *c_creator
    cdef object _finalised

    _metadata ={
        "Name":"", 
        "Title":"", 
        "Creator":"",
        "Publisher":"",
        "Date":"",
        "Description":"",
        "Language":"",
        # Optional
        "LongDescription":"",
        "Licence":"",
        "Tags":"",
        "Flavour":"",
        "Source":"",
        "Counter":"",
        "Scraper":""}

    _article_counter = defaultdict(int)

    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        self.c_creator = ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self.set_metadata(date=datetime.date.today(), language= index_language)
        self._finalised = False

    def set_metadata(self, **kwargs):
        # Converts python case to pascal case. example: long_description-> LongDescription
        pascalize = lambda keyword: "".join(keyword.title().split("_"))

        if "date" in kwargs and isinstance(kwargs['date'],datetime.date):
            kwargs['date'] = kwargs['date'].strftime('%Y-%m-%d')

        new_metadata = {pascalize(key): value for key, value in kwargs.items()}
        self._metadata.update(new_metadata)

    def _update_article_counter(self, ZimArticle article):
        # default dict update
        self._article_counter[article.mimetype] += 1

    def add_article(self, ZimArticle article not None):
        if not article.can_write:
            raise RuntimeError("Article is not good for writing")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object (dereference internal c_article)
        cdef shared_ptr[ZimArticleWrapper] art = make_shared[ZimArticleWrapper](dereference(article.c_article));
        try:
            self.c_creator.addArticle(art)
        else:
            if not article.is_redirect:
                self._update_article_counter(article)

    def finalise(self):
        if not self._finalised:
            #self._write_metadata(self.get_metadata())
            self.c_creator.finalise()
            self._finalised = True
        else:
            raise RuntimeError("ZimCreator already finalised")