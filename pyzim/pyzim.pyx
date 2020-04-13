from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, unique_ptr, make_shared

import datetime
import copy
from collections import defaultdict
from cython.operator import dereference, preincrement

cimport zim_wrapper as zim



#########################
#       ZimArticle      #
#########################


cdef class ZimArticle:
    """ 
    A class to represent a Zim Article. 
    
    Attributes
    ----------
    *c_zim_article : zim.ZimArticle
        a pointer to the C++ article object
    _can_write : bool
        flag if the article is ready for writing

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
    redirect_longurl: str
        the long redirect article url i.e {NAMESPACE}/{redirect_url}
    redirect_url : str
        the redirect article url

    Methods
    -------

    from_read_article(zim.Article art)
        Creates a python ZimArticle from a C++ zim.Article article.
    """
    cdef zim.ZimArticle *c_zim_article
    cdef object _can_write

    VALID_NAMESPACES = ["-","A","B","I","J","M","U","V","W","X"]


    def __cinit__(self, url="", content="", namespace= "A", mimetype= "text/html", title="", redirect_article_url= "",filename="", should_index=True ):

        # Encoding must be set to UTF-8 
        #cdef bytes py_bytes = content.encode(encoding='UTF-8')
        #cdef char* c_string = py_bytes

        bytes_content =b''
        if isinstance(content, str):
            bytes_content = content.encode('UTF-8')
        else:
            bytes_content = content
        
        if namespace not in self.VALID_NAMESPACES:
            raise ValueError("Invalid Namespace")

        c_zim_art = new zim.ZimArticle(ord(namespace),                     # Namespace
                                       url.encode('UTF-8'),                # url
                                       title.encode('UTF-8'),              # title
                                       mimetype.encode('UTF-8'),           # mimeType
                                       redirect_article_url.encode('UTF-8'),# redirectUrl
                                       should_index,                                # shouldIndex
                                       bytes_content)
        self.__setup(c_zim_art)

    def __dealloc__(self):
        if self.c_zim_article != NULL:
            del self.c_zim_article

    #def __eq__(self, other):
    #    if isinstance(other, ZimArticle):
    #        return (self.longurl == other.longurl) and (self.content == other.content) and (self.is_redirect == other.is_redirect)
    #    return False

    cdef __setup(self, zim.ZimArticle *art):
        """Assigns an internal pointer to the wrapped C++ article object.

        A python ZimArticle always maintains a pointer to a wrapped zim.ZimArticle C++ object. 
        The python object reflects the state, accessible with properties, of a wrapped C++ zim.ZimArticle,
        this ensures a valid wrapped article that can be passed to a zim.ZimCreator.

        Parameters
        ----------
        *art : zim.ZimArticle
            Pointer to a C++ article object

        """
        # Set new internal C zim.ZimArticle article
        self.c_zim_article = art



    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(zim.Article art):
        """Creates a python ZimArticle from a C++ zim.Article article.
        
        Parameters
        ----------
        art : zim.ZimArticle
            A C++ zim.Article read with File

        Return
        ------
        

        """
        cdef ZimArticle article = ZimArticle()
        # Construct ZimArticle (zim::writer namespace) from Article (zim namespace) 
        c_zim_art = new zim.ZimArticle(art)
        article.__setup(c_zim_art)
        return article

    @property
    def namespace(self):
        """Get the article's namespace"""
        return chr(self.c_zim_article.ns)

    @namespace.setter
    def namespace(self,new_namespace):
        """Set the article's namespace"""
        if new_namespace not in self.VALID_NAMESPACES:
            raise ValueError("Invalid Namespace")
        self.c_zim_article.ns = ord(new_namespace[0])
        
    @property
    def title(self):
        """Get the article's title"""
        return self.c_zim_article.title.decode('UTF-8')

    @title.setter
    def title(self, new_title):
        """Set the article's namespace"""
        self.c_zim_article.title = new_title.encode('UTF-8')

    @property
    def content(self):
        """Get the article's content"""
        data = self.c_zim_article.content 
        try:
            return data.decode('UTF-8')
        except UnicodeDecodeError:
            return data

    @content.setter
    def content(self, new_content):
        """Set the article's content"""
        if isinstance(new_content,str):
            self.c_zim_article.content = new_content.encode('UTF-8') 
        else:
            self.c_zim_article.content = new_content 

    @property
    def longurl(self):
        """Get the article's long url i.e {NAMESPACE}/{url}"""
        return self.c_zim_article.getUrl().getLongUrl().decode("UTF-8", "strict")

    @property
    def url(self):
        """Get the article's url"""
        return self.c_zim_article.url.decode('UTF-8')
    
    @url.setter
    def url(self, new_url):
        """Set the article's url"""
        self.c_zim_article.url = new_url.encode('UTF-8')

    @property
    def redirect_longurl(self):
        """Get the article's redirect long url i.e {NAMESPACE}/{redirect_url}"""
        return self.c_zim_article.getRedirectUrl().getLongUrl().decode("UTF-8", "strict")

    @property
    def redirect_url(self):
        """Get the article's redirect url"""
        return self.c_zim_article.redirectUrl.decode('UTF-8')

    @redirect_url.setter
    def redirect_url(self, new_redirect_url):
        """Set the article's redirect url"""
        self.c_zim_article.redirectUrl = new_redirect_url.encode('UTF-8')

    @property
    def mimetype(self):
        """Get the article's mimetype"""
        return self.c_zim_article.mimeType.decode('UTF-8')

    @mimetype.setter
    def mimetype(self, new_mimetype):
        """Set the article's mimetype"""
        self.c_zim_article.mimeType = new_mimetype.encode('UTF-8')

    @property
    def is_redirect(self):
        """Get if the article is a redirect"""
        return self.c_zim_article.isRedirect()

    @property
    def can_write(self):
        """Get if the article is valid for writing"""
        # An article must have at least non empty url to be writable
        # Content can be empty if article is a redirect
        if self.longurl and (self.content or self.is_redirect):
            self._can_write = True
        else:
            self._can_write = False
        return self._can_write

    def __repr__(self):
        return f"{self.__class__.__name__}(url={self.longurl}, title=)"

#########################
#       ZimReader       #
#########################

cdef class ZimReader:
    """ 
    A class to represent a Zim File Reader. 
    
    Attributes
    ----------
    *c_file : zim.File
        a pointer to a C++ File object
    *c_search : zim.ZimSearch
        a pointer to a C++ ZimSearch object
    _filename : str
        the file name of the File Reader object
    """

    cdef zim.File *c_file
    cdef zim.ZimSearch *c_search
    cdef object _filename

    _metadata_keys =[
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

    def __cinit__(self, str filename):
        self.c_file = new zim.File(filename.encode('UTF-8'))
        self.c_search = new zim.ZimSearch(self.c_file)

        self._filename = self.c_file.getFilename().decode("UTF-8", "strict")

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    @property
    def filename(self):
        """Get the filename of the ZimReader object"""
        return self._filename

    def get_article(self, url):
        """Get a ZimArticle with a copy of the file article by full url i.e including namespace
        
        Parameters
        ----------
        url : str
            The full url, including namespace, of the article

        Returns
        -------
        ZimArticle
            The ZimArticle object

        Raises
        ------
            RuntimeError
                If an article with the provided long url is not found in the file

        """
        # Read to a zim::Article
        cdef zim.Article art = self.c_file.getArticleByUrl(url.encode('UTF-8'))
        if not art.good():
            raise RuntimeError("Article not found for url")

        article = ZimArticle.from_read_article(art)
        return article

    def get_mandatory_metadata(self):
        """Get the file metadata.

        Returns
        -------
        dict
            A dictionary with the file metadata
        """
        metadata = dict()
        for key in self._metadata_keys:
            try:
                meta_art = self.get_article(f"M/{key}")
            except:
                pass
            else:
                metadata[key] = meta_art.content
        return metadata

    def get_article_by_id(self, id):
        """Get a ZimArticle with a copy of the file article by article id.
        
        Parameters
        ----------
        id : int
            The id of the article

        Returns
        -------
        ZimArticle
            The ZimArticle object

        Raises
        ------
            RuntimeError
                If an article with the provided id is not found in the file

        """

        # Read to a zim::Article
        cdef zim.Article art = self.c_file.getArticle(<int> id)
        if not art.good():
            raise RuntimeError("Article not found for id")

        article = ZimArticle.from_read_article(art)
        return article

    def get_redirect_article(self, ZimArticle article):
        """Get a ZimArticle with a copy of the file pointed article, if any, from a redirecting ZimArticle.
        
        Parameters
        ----------
        article : ZimArticle
            The redirecting article 

        Returns
        -------
        ZimArticle
            The ZimArticle copy of the file redirected article

        Raises
        ------
            RuntimeError
                If the ZimArticle provided is not a redirect article
            RuntimeError
                If the pointed article is not present in the file

        """
        cdef zim.Article art = self.c_file.getArticleByUrl(article.redirect_longurl.encode('UTF-8'))

        if article.is_redirect:
            if not art.good():
                raise RuntimeError("Article not found for redirect url")
            article = ZimArticle.from_read_article(art)
            return article
        else:
            raise RuntimeError("Article is not a redirect article")

    def get_main_page_url(self):
        """Get the file main page url.

        Returns
        -------
        str
            The url of the main page

        TODO Check old formats

        """ 
        cdef zim.Fileheader header = self.c_file.getFileheader()
        cdef zim.Article article
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

    def suggest(self, query):
        """Get a list of the full urls of suggested articles in the file from a query.

        Parameters
        ----------
        query : str
            Query string

        Returns
        -------
        list
            A list with the urls of suggested articles

        """
        results = self.c_search.suggest(query.encode('UTF-8')) 
        return [r.decode("UTF-8", "strict") for r in results]

    def search(self, query):
        """Get a list of the full urls of articles in the file from a search query.

        Parameters
        ----------
        query : str
            Query string

        Returns
        -------
        list
            A list with the urls of articles matching the search query
        """

        results = self.c_search.search(query.encode('UTF-8')) 
        return [r.decode("UTF-8", "strict") for r in results]

    def file_search(self, query, start=0, end=10):
        cdef unique_ptr[zim.Search] search = self.c_file.search(query.encode('UTF-8'),start, end) 
        cdef zim.search_iterator it = dereference(search).begin()
    
        print(dereference(search).get_matches_estimated()) 

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def file_suggestions(self, query, start=0, end=10):
        cdef unique_ptr[zim.Search] search = self.c_file.suggestions(query.encode('UTF-8'),start, end) 
        cdef zim.search_iterator it = dereference(search).begin()
    
        print(dereference(search).get_matches_estimated()) 

        while it != dereference(search).end():
            yield it.get_url().decode('UTF-8')
            preincrement(it)

    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename})"

#########################
#       ZimCreator      #
#########################

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
        zim filename

    """

    cdef zim.ZimCreator *c_creator
    cdef object _finalized
    cdef object _filename
    cdef object _main_page
    cdef object _index_language
    cdef object _min_chunk_size
    cdef object _article_counter
    cdef object _metadata

    _metadata_keys ={
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


    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        self.c_creator = zim.ZimCreator.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self._article_counter = defaultdict(int)
        self._metadata = copy.deepcopy(self._metadata_keys)
        
        self._finalized = False
        self._filename = filename
        self._main_page = self.c_creator.getMainUrl().getLongUrl().decode("UTF-8", "strict")
        self._index_language = index_language
        self._min_chunk_size = min_chunk_size

        self.set_metadata(date=datetime.date.today(), language= index_language)


    #def __dealloc__(self):
    #    if self.c_creator != NULL:
    #        del self.c_creator

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
        if new_url.find('/') == 1:
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


    def add_article(self, ZimArticle article):
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

        # Make a shared pointer to ZimArticle from the ZimArticle object (dereference internal c_zim_article)
        cdef shared_ptr[zim.ZimArticle] art = make_shared[zim.ZimArticle](dereference(article.c_zim_article));

        try:
            self.c_creator.addArticle(art)
        else:
            if not article.is_redirect:
                self._update_article_counter(article)


    def _update_article_counter(self, ZimArticle article):
        # default dict update
        self._article_counter[article.mimetype] += 1

    def get_article_counter_string(self):
        return ";".join(["%s=%s" % (k,v) for (k,v) in self._article_counter.items()])

    def _get_metadata(self):
        # Select non empty keys from _metadata
        metadata = {k: str(v) for k, v in self._metadata.items() if v}

        counter_string = self.get_article_counter_string() 
        if counter_string:
            metadata['Counter'] = counter_string

        return metadata

    def _write_metadata(self, dict metadata):
      
        for key in metadata:
            metadata_article = ZimArticle(url=key, content=metadata[key], namespace= "M",
             mimetype= "text/plain", title=key )
            self.add_article(metadata_article)

    def set_metadata(self, **kwargs):
        # Converts python case to pascal case. example: long_description-> LongDescription
        pascalize = lambda keyword: "".join(keyword.title().split("_"))

        if "date" in kwargs and isinstance(kwargs['date'],datetime.date):
            kwargs['date'] = kwargs['date'].strftime('%Y-%m-%d')

        new_metadata = {pascalize(key): value for key, value in kwargs.items()}
        self._metadata.update(new_metadata)

    def finalize(self):
        """finalize and write added articles to the file.
        
        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized

        """
        if not self._finalized:
            self._write_metadata(self._get_metadata())
            self.c_creator.finalize()
            self._finalized = True
        else:
            raise RuntimeError("ZimCreator already finalized")

    def __repr__(self):
        return f"{self.__class__.__name__}(filename={self.filename})"