from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared

import datetime
from collections import defaultdict
from cython.operator import dereference

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
    namespace: str
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
        the long redirect url i.e {NAMESPACE}/{redirect_url}
    redirect_url : str
        the article url

    Methods
    -------

    gamma(n=1.0)
        Change the photo's gamma exposure.

    """
    cdef zim.ZimArticle *c_zim_article
    cdef object _can_write

    VALID_NAMESPACES = ["-","A","B","I","J","M","U","V","W","X"]


    def __cinit__(self, url="", str content="", namespace= "A", mimetype= "text/html", title="", redirect_article_url= "",filename="", should_index=True ):

        # Encoding must be set to UTF-8 
        #cdef bytes py_bytes = content.encode(encoding='UTF-8')
        #cdef char* c_string = py_bytes
        
        if namespace not in self.VALID_NAMESPACES:
            raise RuntimeError("Invalid Namespace")

        c_zim_art = new zim.ZimArticle(ord(namespace),                     # Namespace
                                       url.encode('UTF-8'),                # url
                                       title.encode('UTF-8'),              # title
                                       mimetype.encode('UTF-8'),           # mimeType
                                       redirect_article_url.encode('UTF-8'),# redirectUrl
                                       should_index,                                # shouldIndex
                                       content.encode('UTF-8'))
        self.__setup(c_zim_art)

    def __dealloc__(self):
        if self.c_zim_article != NULL:
            del self.c_zim_article

    #def __eq__(self, other):
    #    if isinstance(other, ZimArticle):
    #        return (self.longurl == other.longurl) and (self.content == other.content) and (self.is_redirect == other.is_redirect)
    #    return False

    cdef __setup(self, zim.ZimArticle *art):
        """Assigns an internal pointer to the wrapped C++ article object and sets property values.

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

        # An article must have at least non empty url to be writable
        # Content can be empty if article is a redirect
        if self.longurl and (self.content or self.is_redirect):
            self._can_write = True
        else:
            self._can_write = False

    def get_article_properties(self):
        return dict((name, getattr(self, name)) for name in dir(self) if not name.startswith('__') )

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(zim.Article art):
        """Creates a python ZimArticle from a C++ zim.Article article.
        
        Parameters
        ----------
        art : zim.ZimArticle
            A C++ zim.Article read with File

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
            raise RuntimeError("Invalid Namespace")
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
        return self.c_zim_article.content.decode('UTF-8')

    @content.setter
    def content(self, new_content):
        """Set the article's content"""
        self.c_zim_article.content = new_content.encode('UTF-8') 

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
        if self.longurl and (self.content or self.is_redirect):
            self._can_write = True
        else:
            self._can_write = False
        return self._can_write

#########################
#       ZimReader       #
#########################

cdef class ZimReader:
    cdef zim.File *c_file
    cdef zim.ZimSearch *c_search
    cdef object _filename

    def __cinit__(self, str filename):
        self.c_file = new zim.File(filename.encode('UTF-8'))
        self.c_search = new zim.ZimSearch(self.c_file)

        self._filename = self.c_file.getFilename().decode("UTF-8", "strict")

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    @property
    def filename(self):
        return self._filename

    def get_article(self, url):
        # Read to a zim::Article
        cdef zim.Article art = self.c_file.getArticleByUrl(url.encode('UTF-8'))
        if not art.good():
            raise RuntimeError("Article not found for url")

        article = ZimArticle.from_read_article(art)
        return article

    def get_article_by_id(self, id):
        # Read to a zim::Article
        cdef zim.Article art = self.c_file.getArticle(<int> id)
        if not art.good():
            raise RuntimeError("Article not found for url")

        article = ZimArticle.from_read_article(art)
        return article

    def get_redirect_article(self, ZimArticle article):
        cdef zim.Article art = self.c_file.getArticleByUrl(article.redirect_longurl.encode('UTF-8'))

        if article.is_redirect:
            if not art.good():
                raise RuntimeError("Article not found for redirect url")
            article = ZimArticle.from_read_article(art)
            return article
        else:
            raise RuntimeError("Article is not a redirect article")

    def get_main_page_url(self):
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
        return self.c_file.getChecksum().decode("UTF-8", "strict")

    def get_article_count(self):
        return self.c_file.getCountArticles()

    def get_namespaces(self) -> str:
        return self.c_file.getNamespaces().decode("UTF-8", "strict")

    def get_namespaces_count(self, str ns):
        return self.c_file.getNamespaceCount(ord(ns[0]))

    def suggest(self, query):
        results = self.c_search.suggest(query.encode('UTF-8')) 
        return [r.decode("UTF-8", "strict") for r in results]

    def search(self, query):
        results = self.c_search.search(query.encode('UTF-8')) 
        return [r.decode("UTF-8", "strict") for r in results]


#########################
#       ZimCreator      #
#########################

cdef class ZimCreator:
    cdef zim.ZimCreator *c_creator
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

    def __cinit__(self, str filename, str main_page = '', str index_language = 'eng', min_chunk_size = 2048):
        self.c_creator = zim.ZimCreator.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self.set_metadata(date=datetime.date.today(), language= index_language)
        self._finalised = False

    #def __dealloc__(self):
    #    if self.c_creator != NULL:
    #        del self.c_creator

    def add_article(self, ZimArticle article):
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

    def get_metadata(self):
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

    def finalise(self):
        if not self._finalised:
            self._write_metadata(self.get_metadata())
            self.c_creator.finalise()
            self._finalised = True
        else:
            raise RuntimeError("ZimCreator already finalised")
