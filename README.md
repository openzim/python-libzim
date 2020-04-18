
# Setup

```bash
docker-compose build
docker-compose run libzim /bin/bash
```
```bash
python setup.py build_ext -i
python tests/test_libzim.py

# or

./rebuild.sh
./run_tests
```

Example:

```python3
from libzim import ZimArticle, ZimBlob, ZimCreator

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

# Create a ZimTestArticle article

article = ZimTestArticle()
print(article.content)

# Write the articles
import uuid
rnd_str = str(uuid.uuid1()) 

test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"

zim_creator = ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',main_page = "welcome",index_language= "eng", min_chunk_size= 2048)

# Add article to zim file
zim_creator.add_article(article)

# Write article to zim file
zim_creator.finalize()

```
