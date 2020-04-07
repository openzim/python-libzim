
python-libzim
===========

This is the python binding to the [libzim](https://github.com/openzim/libzim).  Read and write
[ZIM](https://openzim.org) files easily in Python.

## Dependencies


## Setup

```bash
docker-compose build
docker-compose run libzim /bin/bash
```
```bash
python setup.py build_ext -i
python tests/test_pyzim.py

# or

./rebuild.sh
./run_tests
```

## Usage

### Writing a Zim file

```python
import pyzim

zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
zim_reader = pyzim.ZimReader(zim_file_path)

article = pyzim.ZimArticle()

# article content

article_title = "Monadical SAS"
article_url = "Monadical_SAS"
article_longurl ="A/Monadical_SAS"
article_mimetype = "text/html"
article_content =  '''<!DOCTYPE html> <html class="client-js"><head><meta charset="UTF-8">
<title>Monadical SAS</title> <h1> Hello, it works Monadical ñññ </h1></html>'''

article.title = article_title
article.url = article_url
article.mimetype = article_mimetype
article.content = article_content


import uuid

rnd_str = str(uuid.uuid1()) 
test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"
zim_creator = pyzim.ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',"welcome","spa",2048)




# Add and write article to second test zim file
zim_creator.add_article(article)
zim_creator.finalise()
```

### Reading a Zim file

```python
import pyzim

# Read an article from a zim file

zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
zim_reader = pyzim.ZimReader(zim_file_path)
zim_test_article_long_url = "A/Albert_Einstein"

read_article = zim_reader.get_article(zim_test_article_long_url)

# Read article properties

print(read_article.longurl)
print (read_article.title)
print(read_article.is_redirect)
print(read_article.can_write)
print(read_article.content[:100])

# Search or get suggestions from a zim file
search = zim_reader.search("Einstein")
print(search)
suggestions = zim_reader.suggest("Einstein")
print(suggestions)

```

## Cookbook

Visit [examples.py](pyzim/examples.py)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0) or later, see
[LICENSE](LICENSE) for more details.