import unittest
import os,sys,inspect

# Import local pyzim module from parent
current_dir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)

import pyzim
# test files https://wiki.kiwix.org/wiki/Content_in_all_languages


# https://wiki.openzim.org/wiki/Metadata

TEST_METADATA = { 
    # Mandatory
    "Name" : "wikipedia_fr_football",
    "Title": "English Wikipedia",
    "Creator": "English speaking Wikipedia contributors",
    "Publisher": "Wikipedia user Foobar",
    "Date": "2009-11-21",
    "Description": "All articles (without images) from the english Wikipedia",
    "Language": "eng",
    # Optional
    "LongDescription": "This ZIM file contains all articles (without images) from the english Wikipedia by 2009-11-10. The topics are ...",
    "Licence": "CC-BY",
    "Tags": "wikipedia;_category:wikipedia;_pictures:no;_videos:no;_details:yes;_ftindex:yes",
    "Flavour": "nopic",
    "Source": "https://en.wikipedia.org/",
    "Counter": "image/jpeg=5;image/gif=3;image/png=2",
    "Scraper": "mwoffliner 1.2.3"
}

class TestZimArticle(unittest.TestCase):
    def setUp(self):

        # Test Zim File
        self.zim_file_path = u"/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"

        # Test article
        self.zim_test_article_long_url = u"A/Albert_Einstein"

        # Test properties

        self.test_article_title = u"Monadical SAS"
        self.test_article_url = u"Monadical_SAS"
        self.test_article_mimetype = u"text/html"
        self.test_article_is_redirect = False
        self.test_article_content =  u'''<!DOCTYPE html>
                                        <html class="client-js"><head>
                                        <meta charset="UTF-8">
                                        <title>Monadical SAS</title>
                                            <h1> Hello it, works </h1>
                                        </html>
                                    '''


        # Zim reader 
        self.zim_reader = pyzim.ZimReader(self.zim_file_path)

    def test_create_from_read_article(self):
        article = self.zim_reader.get_article(self.zim_test_article_long_url)
        self.assertIsInstance(article, pyzim.ZimArticle)
        self.assertEqual(article.url, self.zim_test_article_long_url[2:])

    def test_create_empty_zim_article(self):
        article = pyzim.ZimArticle()
        self.assertIsInstance(article, pyzim.ZimArticle)
        
        article.title = self.test_article_title
        self.assertEqual(article.title, self.test_article_title)

        article.content = self.test_article_content
        self.assertEqual(article.content, self.test_article_content)

        article.url = self.test_article_url
        self.assertEqual(article.url, self.test_article_url)

        article.mimetype = self.test_article_mimetype
        self.assertEqual(article.mimetype, self.test_article_mimetype)

        self.assertEqual(article.is_redirect, self.test_article_is_redirect)
    
    def test_redirect_article(self):
        article = pyzim.ZimArticle()
        #article.namespace = "A"
        article.redirect_url = "Hola"

        self.assertTrue(article.is_redirect)        


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
        self.zim_reader = pyzim.ZimReader(self.zim_file_path)

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
        self.assertIsInstance(results,list)
        self.assertIn(self.zim_test_article_long_url,results)

    def test_search(self):
        results = self.zim_reader.search(self.zim_test_query)
        self.assertIsInstance(results,list)

class TestZimCreator(unittest.TestCase):
    def setUp(self):
        self.test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"

        # Zim Reader 
        self.zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"

         
        self.zim_test_article_long_url = u"A/Albert_Einstein"
        self.zim_test_article_url = self.zim_test_article_long_url[2:]

        self.zim_reader = pyzim.ZimReader(self.zim_file_path)


        # Test properties


        self.test_article_title = u"Monadical SAS"
        self.test_article_url = u"Monadical_SAS"
        self.test_article_longurl =u"A/Monadical_SAS"
        self.test_article_mimetype = u"text/html"
        self.test_article_content =  u'''<!DOCTYPE html>
                                        <html class="client-js"><head>
                                        <meta charset="UTF-8">
                                        <title>Monadical SAS</title>
                                            <h1> Hello, it works Monadical </h1>
                                        </html>'''

    def tearDown(self):
        pass

    def _assert_article_properties(self, written_article, article):

        self.assertEqual(written_article.url, article.url)
        self.assertEqual(written_article.longurl, article.longurl)
        self.assertEqual(written_article.title, article.title)
        self.assertEqual(written_article.content, article.content)
        self.assertEqual(written_article.mimetype, article.mimetype)
        self.assertEqual(written_article.is_redirect, article.is_redirect)


    def _add_article_to_test_zim_file_read_it_back(self, article, delete_zim_file=True):

        # Zim Creator Test file
        import uuid

        rnd_str = str(uuid.uuid1()) 
        zim_creator = pyzim.ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',"welcome","eng",2048)

         # Add and write article to second test zim file
        zim_creator.add_article(article)
        zim_creator.finalise()
        del(zim_creator)



        # Read back article from second test zim file
        test_zim_reader = pyzim.ZimReader(self.test_zim_file_path + '-' + rnd_str + '.zim')
        written_article = test_zim_reader.get_article(article.longurl)

        if delete_zim_file:
            os.remove(self.test_zim_file_path + '-' + rnd_str + '.zim')
 


        return written_article

        
    def test_write_article_read_from_zim_file(self):

        # Read article from first test zim file
        article = self.zim_reader.get_article(self.zim_test_article_long_url)
        self.assertEqual(article.can_write, True)

        # Write article and Read back article from second test zim file
        written_article = self._add_article_to_test_zim_file_read_it_back(article)

        # Assert all article properties
        self._assert_article_properties(written_article,article)


    def test_write_article_created_filled(self):

        article = pyzim.ZimArticle(namespace='A', url = self.test_article_url, title=self.test_article_title, content= self.test_article_content, mimetype = self.test_article_mimetype, should_index = True)
        self.assertIsInstance(article, pyzim.ZimArticle) 
        self.assertEqual(article.can_write, True)


        # Write article and Read back article from second test zim file
        written_article = self._add_article_to_test_zim_file_read_it_back(article, True)

        # Assert all article properties
        self._assert_article_properties(written_article,article)


    def test_write_article_created_empty_then_filled(self):
        # New empty Article
        article = pyzim.ZimArticle()

        self.assertEqual(article.can_write, False)

        article.title = self.test_article_title
        article.url = self.test_article_url
        article.mimetype = self.test_article_mimetype
        article.content = self.test_article_content

        self.assertEqual(article.can_write, True)

        written_article = self._add_article_to_test_zim_file_read_it_back(article, True) 

        # Assert all article properties
        self._assert_article_properties(written_article,article)

    def test_write_redirect_article(self):
        import uuid

        rnd_str = str(uuid.uuid1())

        # Read article from first test zim file
        article = self.zim_reader.get_article(self.zim_test_article_long_url)
        self.assertTrue(article.can_write)

        zim_creator = pyzim.ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',"welcome","eng",2048)

         # Add and write article to second test zim file
        zim_creator.add_article(article)

        # Create Redirect article
        redirect_article = pyzim.ZimArticle()
        redirect_article.namespace = "A"
        redirect_article.title = self.test_article_title
        redirect_article.url = self.test_article_url
        redirect_article.redirect_url = self.zim_test_article_url 

        self.assertTrue(redirect_article.is_redirect)        
        self.assertTrue(redirect_article.can_write)

        zim_creator.add_article(redirect_article)

        # Write both articles
        zim_creator.finalise()
        del(zim_creator)

        # Read back article and redirect from second test zim file
        test_zim_reader = pyzim.ZimReader(self.test_zim_file_path + '-' + rnd_str + '.zim')
        written_article = test_zim_reader.get_article(self.zim_test_article_long_url)
        written_redirect_article = test_zim_reader.get_article(self.test_article_longurl) 

        # Test redirect
        self.assertTrue(written_redirect_article.is_redirect)
        self.assertEqual(written_article.longurl, written_redirect_article.redirect_longurl)

        #os.remove(self.test_zim_file_path + '-' + rnd_str + '.zim')

    def test_zim_file_writen_metadata(self):
        import uuid

        rnd_str = str(uuid.uuid1())
        zim_creator = pyzim.ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',"welcome","spa",2048)

        # New empty Article
        article = pyzim.ZimArticle()

        self.assertEqual(article.can_write, False)

        article.title = self.test_article_title
        article.url = self.test_article_url
        article.mimetype = self.test_article_mimetype
        article.content = self.test_article_content

        self.assertEqual(article.can_write, True)

        # Set metadata
        import datetime

        test_date = datetime.date(1900, 1, 1)


        zim_creator.set_metadata(date=test_date)
        zim_creator.set_metadata(title="Monadical SAS",creator="python-libzim",language="spa,eng,ces")
        zim_creator.finalise()
        
        test_zim_reader = pyzim.ZimReader(self.test_zim_file_path + '-' + rnd_str + '.zim')

        metadata_title = test_zim_reader.get_article("M/Date")
        self.assertEqual(metadata_title.content, str(test_date))

        metadata_title = test_zim_reader.get_article("M/Title")
        self.assertEqual(metadata_title.content, u"Monadical SAS")

        metadata_creator = test_zim_reader.get_article("M/Creator")
        self.assertEqual(metadata_creator.content, u"python-libzim")

        metadata_language = test_zim_reader.get_article("M/Language")
        self.assertEqual(metadata_language.content, u"spa,eng,ces")

        metadata_counter =  test_zim_reader.get_article("M/Counter")
        print(metadata_counter.content)

                

if __name__ == '__main__':
    unittest.main()