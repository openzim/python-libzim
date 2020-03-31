from libcpp.string cimport string
from libc.stdint cimport uint32_t, uint64_t
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
    _namespace : str
        the article namespace
    _title : str
        the article title
    _content : str
        the article content
    _longurl : str
        the article long url i.e {NAMESPACE}/{redirect_url}
    _url : str
        the article url
    _mimetype : str
        the article mimetype
    _is_redirect : bool
        flag if the article is a redirect 
    _can_write : bool
        flag if the article is ready for writing
    _redirect_longurl: str
        the long redirect url i.e {NAMESPACE}/{redirect_url}
    _redirect_url : str
        the article url

    Methods
    -------

    gamma(n=1.0)
        Change the photo's gamma exposure.

    """
    cdef zim.ZimArticle *c_zim_article
    cdef object _namespace
    cdef object _title
    cdef object _content
    cdef object _longurl
    cdef object _url
    cdef object _mimetype
    cdef object _is_redirect
    cdef object _can_write
    cdef object _redirect_longurl
    cdef object _redirect_url

    VALID_NAMESPACES = ["-","A","B","I","J","M","U","V","W","X"]


    def __cinit__(self, url="", content="", namespace= "A", mimetype= "text/html", title="", redirect_article_url= "", article_id = "",filename="", should_index=True ):

        # Encoding must be set to utf-8 
        cdef bytes py_bytes = content.encode(encoding='UTF-8')
        cdef char* c_string = py_bytes
        
        if not article_id:
            article_id = f"{namespace}/{url}"

        if namespace not in self.VALID_NAMESPACES:
            raise RuntimeError("Invalid Namespace")

        c_zim_art = new zim.ZimArticle(ord(namespace),                     # Namespace
                                       article_id.encode('utf-8'),         # Article index
                                       url.encode('utf-8'),                # url
                                       title.encode('utf-8'),              # title
                                       mimetype.encode('utf-8'),           # mimeType
                                       redirect_article_url.encode('utf-8'),# redirectUrl
                                       filename.encode('utf-8'),           # filename
                                       should_index,                       # shouldIndex
                                       c_string,                           # data buffer
                                       len(c_string))                      # data buffer lengt   
    
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

        # Delete old internal C zim.ZimArticle article if any
        if self.c_zim_article != NULL:
            del self.c_zim_article

        # Set new internal C zim.ZimArticle article
        self.c_zim_article = art

        # Setup members
        self._title = self.c_zim_article.getTitle().decode('utf-8') 

        b = self.c_zim_article.getData()
        self._content = b.data()[:b.size()]

        self._longurl = self.c_zim_article.getUrl().getLongUrl().decode('utf-8') 
        self._url = self._longurl[2:]        
        self._namespace = self._longurl[0]

        self._redirect_longurl = self.c_zim_article.getRedirectUrl().getLongUrl().decode('utf-8')
        self._redirect_url = self._redirect_longurl[2:]  

        self._mimetype = self.c_zim_article.getMimeType()
        self._is_redirect = self.c_zim_article.isRedirect()
        
        # An article must have at least non empty url to be writable
        # Content can be empty if article is a redirect
        if self._longurl.strip() and (self._content.strip() or self._is_redirect):
            self._can_write = True
        else:
            self._can_write = False

    def get_article_properties(self):
        return dict((name, getattr(self, name)) for name in dir(self) if not name.startswith('__') )

    # props is a dictionary, Cython cdef can't use **kwargs
    cdef update_c_zim_article_from_properties(self, props):

        # Encoding must be set to utf-8 
        cdef bytes py_bytes = props.get("content","").encode(encoding='UTF-8')
        cdef char* c_string = py_bytes

        ns = ord(props["namespace"])
        article_id = props.get("article_id","")
        url = props["url"]
        title = props["title"]
        mimetype = props["mimetype"]
        redirect_article_url = props.get("redirect_url")
        filename = props.get("filename","")
        should_index = props.get("should_index",True)


        c_zim_art = new zim.ZimArticle(ns,                                 # Namespace
                                       article_id.encode('utf-8'),         # Article index
                                       url.encode('utf-8'),                # url
                                       title.encode('utf-8'),              # title
                                       mimetype.encode('utf-8'),           # mimeType
                                       redirect_article_url.encode('utf-8'),# redirectAid
                                       filename.encode('utf-8'),           # filename
                                       should_index,                       # shouldIndex
                                       c_string,                           # data buffer
                                       len(c_string))                      # data buffer lengt  
        

        self.__setup(c_zim_art) 

    def _update_property(self, **kwargs):
        properties = self.get_article_properties()
        properties.update(kwargs)

        self.update_c_zim_article_from_properties(properties)

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_read_article(zim.Article art):
        """Creates a python ZimArticle from a C++ zim.Article article.

        Retu
        

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
        return self._namespace

    @namespace.setter
    def namespace(self,new_namespace):
        """Set the article's namespace"""
        self._update_property(namespace=new_namespace)

    @property
    def title(self):
        """Get the article's title"""
        return self._title

    @title.setter
    def title(self, new_title):
        """Set the article's namespace"""
        self._update_property(title=new_title)

    @property
    def content(self):
        """Get the article's content"""
        return self._content

    @content.setter
    def content(self, new_content):
        """Set the article's content"""
        self._update_property(content=new_content)

    @property
    def longurl(self):
        """Get the article's long url i.e {NAMESPACE}/{url}"""
        return self._longurl

    @property
    def url(self):
        """Get the article's url"""
        return self._url
    
    @url.setter
    def url(self, new_url):
        """Set the article's url"""
        self._update_property(url=new_url)

    @property
    def redirect_longurl(self):
        """Get the article's redirect long url i.e {NAMESPACE}/{redirect_url}"""
        return self._redirect_longurl

    @property
    def redirect_url(self):
        """Get the article's redirect url"""
        return self._redirect_url

    @redirect_url.setter
    def redirect_url(self, new_redirect_url):
        """Set the article's redirect url"""
        self._update_property(redirect_url=new_redirect_url)

    @property
    def mimetype(self):
        """Get the article's mimetype"""
        return self._mimetype

    @mimetype.setter
    def mimetype(self, new_mimetype):
        """Set the article's mimetype"""
        self._update_property(mimetype=new_mimetype)

    @property
    def is_redirect(self):
        """Get if the article is a redirect"""
        return self._is_redirect

    @property
    def can_write(self):
        """Get if the article is valid for writing"""
        return self._can_write

    # ZimArticle.good only available for zim:Article
    #def _good(self):
    #    return self.c_zim_article.good()

    # ZimArticle.getRedirectArticle only available for zim:Article
    #def get_redirect_article(self):
    #    cdef Article article = Article()
    #    cdef zim.Article art = self.c_article.getRedirectArticle()
    #    if not art.good():
    #        raise RuntimeError("Article is not a redirectArticle")
    #    article.setup(art)
    #    return article



#########################
#       ZimReader       #
#########################

cdef class ZimReader:
    cdef zim.File *c_file
    cdef zim.ZimSearch *c_search
    cdef object _filename

    def __cinit__(self, string filename):
        self.c_file = new zim.File(filename.encode('utf-8'))
        self.c_search = new zim.ZimSearch(self.c_file)

        self._filename = self.c_file.getFilename().decode('utf-8')

    def __dealloc__(self):
        if self.c_file != NULL:
            del self.c_file

    @property
    def filename(self):
        return self._filename

    def get_article(self, url):
        # Read to a zim::Article
        cdef zim.Article art = self.c_file.getArticleByUrl(url.encode('utf-8'))
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
        cdef zim.Article art = self.c_file.getArticleByUrl(article.redirect_longurl.encode('utf-8'))

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
            return article.getLongUrl();

        # TODO Ask about the old format, check libzim for tests
        # Handle old zim where header has no mainPage.
        # (We need to get first article in the zim)
        article = self.c_file.getArticle(<int> 0)
        if article.good():
            return article.getLongUrl()

    def get_checksum(self):
        return self.c_file.getChecksum().encode('utf-8')

    def get_article_count(self):
        return self.c_file.getCountArticles()

    def get_namespaces(self):
        return self.c_file.getNamespaces()

    def get_namespaces_count(self, ns):
        return self.c_file.getNamespaceCount(ord(ns))

    def suggest(self, query):
        results = self.c_search.suggest(query.encode('utf-8')) 
        return results

    def search(self, query):
        results = self.c_search.search(query.encode('utf-8')) 
        return results


#########################
#       ZimCreator      #
#########################

cdef class ZimCreator:
    cdef zim.ZimCreator *c_creator

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

    def __cinit__(self, filename, main_page = '', index_language = 'eng', min_chunk_size = 2048):
        self.c_creator = zim.ZimCreator.create(filename, main_page, index_language, <int> min_chunk_size)

        self.set_metadata(date=datetime.date.today(), language= index_language)

    #def __dealloc__(self):
    #    if self.c_creator != NULL:
    #        del self.c_creator

    def add_article(self, ZimArticle article):
        if not article.can_write:
            raise RuntimeError("Article is not good for writing")

        # Make a shared pointer to ZimArticle from the ZimArticle object (deref internal c_zim_article)
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

    def _write_metadata(self):
        # Select non empty keys from _metadata
        metadata = {k: str(v) for k, v in self._metadata.items() if v}
        metadata['Counter'] = self.get_article_counter_string()

        for key in metadata:
            metadata_article = ZimArticle(url=key, content=metadata[key], namespace= "M",
             mimetype= "text/plain", title=key )
            self.add_article(metadata_article)

    def set_metadata(self, **kwargs):
        # Converts python case to pascal case. example: long_description-> LongDescription
        pascalize = lambda keyword: "".join(keyword.title().split("_"))

        if "date" in kwargs and isinstance(kwargs['date'],datetime.date):
            kwargs['date'] = kwargs['date'].strftime('%Y-%m-%d')

        metadata = {pascalize(key): value for key, value in kwargs.items()}
        self._metadata.update(metadata)

    def finalise(self):
        self._write_metadata()
        self.c_creator.finalise()