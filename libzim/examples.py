from libzim import ZimArticle, ZimBlob, ZimCreator

class ZimTestArticle(ZimArticle):

    def __init__(self, url, title, content):
        ZimArticle.__init__(self)
        self.url = url
        self.title = title
        self.content = content

    def is_redirect(self):
        return False

    def get_url(self):
        return f"A/{self.url}"

    def get_title(self):
        return f"{self.title}"
    
    def get_mime_type(self):
        return "text/html"
    
    def get_filename(self):
        return ""
    
    def should_compress(self):
        return True

    def should_index(self):
        return True

    def get_data(self):
        return ZimBlob(self.content)

# Create a ZimTestArticle article

content = '''<!DOCTYPE html> 
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical</title>
                </head>
                <h1> ñññ Hello, it works ñññ </h1></html>'''

content2 = '''<!DOCTYPE html> 
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical 2</title>
                </head>
                <h1> ñññ Hello, it works 2 ñññ </h1></html>'''

article = ZimTestArticle("Monadical_SAS", "Monadical", content)
article2 = ZimTestArticle("Monadical_2", "Monadical 2", content2)

print(article.content)

# Write the article
import uuid
rnd_str = str(uuid.uuid1()) 

test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"

zim_creator = ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',main_page = "Monadical",index_language= "eng", min_chunk_size= 2048)

# Add articles to zim file
zim_creator.add_article(article)
zim_creator.add_article(article2)

# Set mandatory metadata
if not zim_creator.mandatory_metadata_ok():
    zim_creator.update_metadata(creator='python-libzim',description='Created in python',name='Hola',publisher='Monadical',title='Test Zim')

print(zim_creator._get_metadata())

# Write articles to zim file
zim_creator.finalize()


# Example using context manager to ensure finalize is called.

rnd_str = str(uuid.uuid1())

with ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim') as zc:
    zc.add_article(article)
    zc.add_article(article2)
    zc.update_metadata(creator='python-libzim',
                       description='Created in python',
                       name='Hola',publisher='Monadical',
                       title='Test Zim')

