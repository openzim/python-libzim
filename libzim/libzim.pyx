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
    cdef bytes ref_content

    def __cinit__(self, content):
        if isinstance(content, str):
            self.ref_content = content.encode('UTF-8')
        else:
            self.ref_content = content
        self.c_blob = new Blob(<char *> self.ref_content, len(self.ref_content))

    def __dealloc__(self):
        if self.c_blob != NULL:
            del self.c_blob


#########################
#       ZimArticle      #
#########################

cdef class ZimArticle:
    cdef ZimArticleWrapper* c_article
    cdef ZimBlob blob

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

    def _get_data(self):
        self.blob = self.get_data()
        return self.blob

    def get_data(self):
        raise NotImplementedError

    @property
    def mimetype(self):
        return self.c_article.getMimeType().decode('UTF-8')

#------ Helper for pure virtual methods --------

cdef get_article_method_from_object_ptr(void *ptr, string method, int *error):
    cdef ZimArticle art = <ZimArticle>(ptr)
    try:
        func = getattr(art, method.decode('UTF-8'))
    except AttributeError:
        error[0] = 1
        raise 
    else:
        error[0] = 0
        return func

#------- ZimArticle pure virtual methods --------

cdef public api: 
    string string_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a string"""
        func = get_article_method_from_object_ptr(ptr, method, error)         
        ret_str = func()
        return ret_str.encode('UTF-8')

    Blob blob_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a Blob"""
        cdef ZimBlob blob

        func = get_article_method_from_object_ptr(ptr, method, error) 
        blob = func()
        return dereference(blob.c_blob)

    bool bool_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning a bool"""
        func = get_article_method_from_object_ptr(ptr, method, error) 
        return func() 

    uint64_t int_cy_call_fct(void *ptr, string method, int *error):
        """Lookup and execute a pure virtual method on ZimArticle returning an int"""
        func = get_article_method_from_object_ptr(ptr, method, error) 
        return <uint64_t> func()

#########################
#       ZimCreator      #
#########################

#TODO Write metadata

class ZimMetadataArticle(ZimArticle):

    def __init__(self,url, metadata_content):
        ZimArticle.__init__(self)
        self.url = url
        self.metadata_content = metadata_content

    def is_redirect(self):
        return False

    def get_url(self):
        return f"M/{self.url}"

    def get_title(self):
        return ""
    
    def get_mime_type(self):
        return "text/plain"
    
    def get_filename(self):
        return ""
    
    def should_compress(self):
        return True

    def should_index(self):
        return False

    def get_data(self):
        return ZimBlob(self.metadata_content)


MANDATORY_METADATA_KEYS =[
        "Name", 
        "Title", 
        "Creator",
        "Publisher",
        "Date",
        "Description",
        "Language"]
        # Optional
        #"LongDescription",
        #"Licence",
        #"Tags",
        #"Flavour",
        #"Source",
        #"Counter",
        #"Scraper"]

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
    _article_counter
        Zim file article counter
    _metadata
        Zim file metadata
    """
    
    cdef ZimCreatorWrapper *c_creator
    cdef bool _finalized
    cdef object _filename
    cdef object _main_page
    cdef object _index_language
    cdef object _min_chunk_size
    cdef object _article_counter
    cdef dict __dict__

    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        """Constructs a ZimCreator from parameters.
        Parameters
        ----------
        filename : str
            Zim file path
        main_page : str
            Zim file main page
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
        self._metadata = {k:None for k in MANDATORY_METADATA_KEYS}
        
        self._article_counter = defaultdict(int)
        self.update_metadata(date=datetime.date.today(), language= index_language)

    
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

    def get_article_counter_string(self):
        return ";".join(["%s=%s" % (k,v) for (k,v) in self._article_counter.items()])

    def _get_metadata(self):
        metadata =  self._metadata

        counter_string = self.get_article_counter_string() 
        if counter_string:
            metadata['Counter'] = counter_string

        return metadata

    def mandatory_metadata_ok(self):
        """Flag if mandatory metadata is complete and not empty"""
        metadata_item_ok = [self._metadata[k] for k in MANDATORY_METADATA_KEYS]
        return all(metadata_item_ok)

    def update_metadata(self, **kwargs):
        "Updates article metadata"""
        # Converts python case to pascal case. example: long_description-> LongDescription
        pascalize = lambda keyword: "".join(keyword.title().split("_"))

        if "date" in kwargs and isinstance(kwargs['date'],datetime.date):
            kwargs['date'] = kwargs['date'].strftime('%Y-%m-%d')

        new_metadata = {pascalize(key): value for key, value in kwargs.items()}
        self._metadata.update(new_metadata)

    def _update_article_counter(self, ZimArticle article not None):
        # default dict update
        self._article_counter[article.get_mime_type().strip()] += 1

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

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object (dereference internal c_article)
        cdef shared_ptr[ZimArticleWrapper] art = make_shared[ZimArticleWrapper](dereference(article.c_article));
        try:
            self.c_creator.addArticle(art)
        except:
            raise
        else:
            if not article.is_redirect():
                self._update_article_counter(article)

    def write_metadata(self, dict metadata):
        for key in metadata:
            metadata_article = ZimMetadataArticle(url=key, metadata_content=metadata[key])
            self.add_article(metadata_article)

    def finalize(self):
        """finalize and write added articles to the file.
        
        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """
        if  self._finalized:
            raise RuntimeError("ZimCreator already finalized")

        self.write_metadata(self._get_metadata())
        self.c_creator.finalize()
        self._finalized = True
    
    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename})"