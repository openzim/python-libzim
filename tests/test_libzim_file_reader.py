import unittest
import os,sys,inspect

# Import local libzim module from parent
current_dir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)

from libzim import ZimFileReader, ZimFileArticle

class TestZimReader(unittest.TestCase):

    def setUp(self):

        # Test file
        self.zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
        self.zim_test_file_main_page_url = u"A/index"
        self.zim_test_file_num_articles = 22027
        self.zim_test_file_namespaces = u"-AIMX"
        self.zim_file_checksum = u"99ea7a5598c6040c4f50b8ac0653b703"

        # Test article
        self.zim_test_article_long_url = u"A/Albert_Einstein"
        self.zim_test_article_title = u"Albert Einstein"
        self.zim_test_article_mimetpe = u"text/html"
        self.zim_test_article_id = 663

        # Test query

        self.zim_test_query = u"Einstein"

        # Zim reader 
        self.zim_reader = ZimFileReader(self.zim_file_path)

    def test_zim_filename(self):
        self.assertEqual(self.zim_reader.filename, self.zim_file_path)

    def test_zim_checksum(self):
        self.assertEqual(self.zim_reader.get_checksum(),self.zim_file_checksum)

    def test_zim_read(self):
        article = self.zim_reader.get_article(self.zim_test_article_long_url)

        self.assertEqual(article.longurl,self.zim_test_article_long_url)
        self.assertEqual(article.title, self.zim_test_article_title)
        self.assertEqual(article.url, self.zim_test_article_long_url[2:])
        self.assertEqual(article.mimetype, self.zim_test_article_mimetpe)

    def test_get_article_by_id(self):
        # TODO check 653, 654, 667 redirect
        article = self.zim_reader.get_article_by_id(self.zim_test_article_id)
        self.assertEqual(article.longurl,self.zim_test_article_long_url)
        self.assertEqual(article.title, self.zim_test_article_title)
        self.assertEqual(article.url, self.zim_test_article_long_url[2:])
        self.assertEqual(article.mimetype, self.zim_test_article_mimetpe) 


    def test_get_main_page_url(self):
        self.assertEqual(self.zim_reader.get_main_page_url(),self.zim_test_file_main_page_url)
    
    def test_get_article_count(self):
        self.assertEqual(self.zim_reader.get_article_count(), self.zim_test_file_num_articles)

    def test_get_namespaces(self):
        self.assertEqual(self.zim_reader.get_namespaces(), self.zim_test_file_namespaces)

    def test_namespace_count(self):
        namespaces = self.zim_reader.get_namespaces()
        num_articles = 0
        for ns in namespaces:
            num_articles += self.zim_reader.get_namespaces_count(ns) 
        self.assertEqual(self.zim_reader.get_article_count(),num_articles)

    def test_suggest(self):
        results =  self.zim_reader.suggest(self.zim_test_query)
        self.assertIn(self.zim_test_article_long_url,list(results))

    def test_search(self):
        results = self.zim_reader.search(self.zim_test_query)
        self.assertIsInstance(list(results),list)