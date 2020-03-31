
# Setup

```bash
     $ docker-compose build
    $ docker-compose run libzim /bin/bash
```
```bash
python setup.py build_ext -i
python tests/test_pyzim.py

# or

./rebuild.sh
./run_tests
```

Example:

import pyzim

zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
zim_reader = pyzim.ZimReader(zim_file_path)

article = pyzim.ZimArticle()

# article content

article_title = u"Monadical SAS"
article_url = u"Monadical_SAS"
article_longurl =u"A/Monadical_SAS"
article_mimetype = u"text/html"
article_content =  u'''<!DOCTYPE html> <html class="client-js"><head><meta charset="UTF-8">
<title>Monadical SAS</title> <h1> Hello, it works Monadical ñññ </h1></html>'''

article.title = article_title
article.url = article_url
article.mimetype = article_mimetype
article.content = article_content


import uuid

rnd_str = str(uuid.uuid1()) 
test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"
zim_creator = pyzim.ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',"welcome","spa",2048)

out_content = '''<!DOCTYPE html>
<html class="client-js"><head>
  <meta charset="UTF-8">
  <title>Albert Einstein</title>
  <h1> Hola Funciona ññññ Afueerraaaa</h1>
  </html>
  '''


zim_creator.add_art(out_content)



# Add and write article to second test zim file
zim_creator.add_article(article)
zim_creator.finalise()