cimport libzim
cimport cpython.ref as cpy_ref
from cython.operator import dereference, preincrement

from libc.stdint cimport uint32_t, uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared

from contextlib import contextmanager


import datetime

from collections import defaultdict

#########################
#       ZimBlob         #
#########################

cdef class ZimBlob:
    cdef Blob* c_blob
    cdef object ref_content
    
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
    *c_creator : ZimCreator
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

    
@contextmanager
def zimcreator(*args, **kwds):
    """Context manager version of ZimCreator that calls .finalize() automatically on exit"""
    zimcreator = ZimCreator(*args, **kwds)
    try:
        yield zimcreator
    finally:
        zimcreator.finalize()

#########################
#    ZimFileArticle     # 
########################

cdef class ZimFileArticle:
    """ 
    A class to represent a Zim File Article. 
    
    Attributes
    ----------
    *c_article : Article (zim::)
        a pointer to the C++ article object

    Properties
    -----------
    namespace : str
        the article namespace
    title : str
        the article title
    content : str
        the article content
    longurl : str
        the article long url i.e {NAMESPACE}/{redirect_url}
    url : str
        the article url
    mimetype : str
        the article mimetype
    is_redirect : bool
        flag if the article is a redirect 

    Methods
    -------
    from_read_article(zim.Article art)
        Creates a python ZimArticle from a C++ zim.Article article.
    """
    cdef Article c_article

    #def __eq__(self, other):
    #    if isinstance(other, ZimArticle):
    #        return (self.longurl == other.longurl) and (self.content == other.content) and (self.is_redirect == other.is_redirect)
    #    return False

    cdef __setup(self, Article art):
        """Assigns an internal pointer to the wrapped C++ article object.
   
        Parameters
        ----------
        *art : Article
            Pointer to a C++ (zim::) article object
        """
        # Set new internal C zim.ZimArticle article
        self.c_article = art



    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(Article art):
        """Creates a python ZimFileArticle from a C++ Article (zim::).
        
        Parameters
        ----------
        art : Article
            A C++ Article read with File
        Return
        ------
        
        """
        cdef ZimFileArticle article = ZimFileArticle()
        article.__setup(art)
        return article

    @property
    def namespace(self):
        """Get the article's namespace"""
        ns = self.c_article.getNamespace()
        return chr(ns)
        
    @property
    def title(self):
        """Get the article's title"""
        return self.c_article.getTitle().decode('UTF-8')

    @property
    def content(self):
        """Get the article's content"""
        cdef Blob blob = self.c_article.getData(<int> 0)
        data =  blob.data()[:blob.size()]
        return data

    @property
    def longurl(self):
        """Get the article's long url i.e {NAMESPACE}/{url}"""
        return self.c_article.getLongUrl().decode("UTF-8", "strict")

    @property
    def url(self):
        """Get the article's url"""
        return self.c_article.getUrl().decode("UTF-8", "strict")

    @property
    def mimetype(self):
        """Get the article's mimetype"""
        return self.c_article.getMimeType().decode('UTF-8')

    @property
    def is_redirect(self):
        """Get if the article is a redirect"""
        return self.c_article.isRedirect()

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.longurl}, title=)"




#########################
#    ZimFileReader      #
#########################

cdef class ZimFileReader:
    """ 
    A class to represent a Zim File Reader. 
    
    Attributes
    ----------
    *c_file : File
        a pointer to a C++ File object
    _filename : str
        the file name of the File Reader object
    """

    cdef File *c_file
    cdef object _filename

    def __cinit__(self, str filename):
        """Constructs a ZimFileReader from full zim file path.
        Parameters
        ----------
        filename : str
            Full path to a zim file
        """

        self.c_file = new File(filename.encode('UTF-8'))
        self._filename = self.c_file.getFilename().decode("UTF-8", "strict")

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    @property
    def filename(self):
        """Get the filename of the ZimFileReader object"""
        return self._filename

    def get_article(self, url):
        """Get a ZimFileArticle with a copy of the file article by full url i.e including namespace
        
        Parameters
        ----------
        url : str
            The full url, including namespace, of the article
        Returns
        -------
        ZimFileArticle
            The ZimFileArticle object
        Raises
        ------
            RuntimeError
                If an article with the provided long url is not found in the file
        """
        # Read to a zim::Article
        cdef Article art = self.c_file.getArticleByUrl(url.encode('UTF-8'))
        if not art.good():
            raise RuntimeError("Article not found for url")

        article = ZimFileArticle.from_read_article(art)
        return article

    def get_mandatory_metadata(self):
        """Get the file metadata.
        Returns
        -------
        dict
            A dictionary with the file metadata
        """
        metadata = dict()
        for key in MANDATORY_METADATA_KEYS:
            try:
                meta_art = self.get_article(f"M/{key}")
            except:
                pass
            else:
                metadata[key] = meta_art.content
        return metadata

    def get_article_by_id(self, id):
        """Get a ZimFileArticle with a copy of the file article by article id.
        
        Parameters
        ----------
        id : int
            The id of the article
        Returns
        -------
        ZimFileArticle
            The ZimFileArticle object
        Raises
        ------
            RuntimeError
                If an article with the provided id is not found in the file
        """

        # Read to a zim::Article
        cdef Article art = self.c_file.getArticle(<int> id)
        if not art.good():
            raise RuntimeError("Article not found for id")

        article = ZimFileArticle.from_read_article(art)
        return article

    def get_main_page_url(self):
        """Get the file main page url.
        Returns
        -------
        str
            The url of the main page
        TODO Check old formats
        """ 
        cdef Fileheader header = self.c_file.getFileheader()
        cdef Article article
        if header.hasMainPage():
            article = self.c_file.getArticle(header.getMainPage())
            return article.getLongUrl().decode("UTF-8", "strict");

        # TODO Ask about the old format, check libzim for tests
        # Handle old zim where header has no mainPage.
        # (We need to get first article in the zim)
        article = self.c_file.getArticle(<int> 0)
        if article.good():
            return article.getLongUrl().decode("UTF-8", "strict")

    def get_checksum(self):
        """Get the file checksum.
        Returns
        -------
        str
            The file checksum
        """
        return self.c_file.getChecksum().decode("UTF-8", "strict")

    def get_article_count(self):
        """Get the file article count.
        Returns
        -------
        int
            The total number of articles from the file
        """
        return self.c_file.getCountArticles()

    def get_namespaces(self) -> str:
        """Get the namespaces.

        Returns
        -------
        str
            A string containing all namespaces in the file

        """
        return self.c_file.getNamespaces().decode("UTF-8", "strict")

    def get_namespaces_count(self, str ns):
        """Get article count from a namespaces.
        Returns
        -------
        int
            The total number of articles from the namespace
        """
        return self.c_file.getNamespaceCount(ord(ns[0]))

    def suggest(self, query, start=0, end=10):
        """Get an iterator of the full urls of suggested articles in the file from a title query.
        Parameters
        ----------
        query : str
            Title query string
        start : int
            Iterator start (default 0)
        end : end
            Iterator end (default 10)
        Returns
        -------
        iterator
            An interator with the urls of suggested articles starting from start position
        """
        cdef unique_ptr[Search] search = self.c_file.suggestions(query.encode('UTF-8'),start, end) 
        cdef search_iterator it = dereference(search).begin()

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def search(self, query, start=0, end=10):
        """Get an iterator of the full urls of articles in the file from a search query.
        Parameters
        ----------
        query : str
            Query string
        start : int
            Iterator start (default 0)
        end : end
            Iterator end (default 10)
        Returns
        -------
        iterator
            An iterator with the urls of articles matching the search query starting from start position
        """

        cdef unique_ptr[Search] search = self.c_file.search(query.encode('UTF-8'),start, end) 
        cdef search_iterator it = dereference(search).begin()
    
        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def get_search_results_count(self, query):
        """Get search results counts for a query.
        Parameters
        ----------
        query : str
            Query string
        Returns
        -------
        int
            Number of search results
        """
        cdef unique_ptr[Search] search = self.c_file.search(query.encode('UTF-8'),0, 1) 
        return dereference(search).get_matches_estimated()
    
    def get_suggestions_results_count(self, query):
        """Get suggestions results counts for a query.
        Parameters
        ----------
        query : str
            Query string
        Returns
        -------
        int
            Number of article suggestions
        """
        cdef unique_ptr[Search] search = self.c_file.suggestions(query.encode('UTF-8'),0 , 1) 
        return dereference(search).get_matches_estimated()

    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename})"
