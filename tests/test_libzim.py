import unittest
import os,sys,inspect

# Import local libzim module from parent
current_dir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)

from libzim import ZimArticle, ZimBlob, ZimCreator

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
    "Longdescription": "This ZIM file contains all articles (without images) from the english Wikipedia by 2009-11-10. The topics are ...",
    "Licence": "CC-BY",
    "Tags": "wikipedia;_category:wikipedia;_pictures:no;_videos:no;_details:yes;_ftindex:yes",
    "Flavour": "nopic",
    "Source": "https://en.wikipedia.org/",
    "Counter": "image/jpeg=5;image/gif=3;image/png=2",
    "Scraper": "sotoki 1.2.3"
}

class ZimTestArticle(ZimArticle):
    content = '''<!DOCTYPE html> 
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical</title>
                </head>
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
       

class TestZimCreator(unittest.TestCase):
    def setUp(self):
        self.test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"
         
        # Test article
        self.test_article =  ZimTestArticle()

    def tearDown(self):
        pass

    def _assert_article_properties(self, written_article, article):
        pass
    
    def _add_article_to_test_zim_file_read_it_back(self, article, delete_zim_file=True):
        pass

    def test_write_article(self):
        import uuid
        rnd_str = str(uuid.uuid1()) 
        zim_creator = ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',main_page = "welcome",index_language= "eng", min_chunk_size= 2048)
        zim_creator.add_article(self.test_article)
        # Set mandatory metadata
        zim_creator.update_metadata(creator='python-libzim',description='Created in python',name='Hola',publisher='Monadical',title='Test Zim')
        zim_creator.finalize()

    def test_article_metadata(self):
        import uuid
        rnd_str = str(uuid.uuid1()) 
        zim_creator = ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',main_page = "welcome",index_language= "eng", min_chunk_size= 2048)
        zim_creator.update_metadata(**TEST_METADATA)
        self.assertEqual(zim_creator._get_metadata(), TEST_METADATA)

    def test_check_mandatory_metadata(self):
        import uuid
        rnd_str = str(uuid.uuid1()) 
        zim_creator = ZimCreator(self.test_zim_file_path + '-' + rnd_str + '.zim',main_page = "welcome",index_language= "eng", min_chunk_size= 2048)
        self.assertFalse(zim_creator.mandatory_metadata_ok())
        zim_creator.update_metadata(creator='python-libzim',description='Created in python',name='Hola',publisher='Monadical',title='Test Zim')
        self.assertTrue(zim_creator.mandatory_metadata_ok())



if __name__ == '__main__':
    unittest.main()