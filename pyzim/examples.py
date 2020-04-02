import pyzim

test_content = '''<!DOCTYPE html> 
<html class="client-js">
<head><meta charset="UTF-8">
<title>Monadical</title>
<h1> ñññ Hello, it works ñññ </h1></html>'''


# Read an article from a zim file

zim_file_path = u"/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
zim_reader = pyzim.ZimReader(zim_file_path)
zim_test_article_long_url = u"A/Albert_Einstein"

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

# Get the total number of articles
print (f"Number of articles: {str(zim_reader.get_article_count())}")

# Get the file namespaces

namespaces = zim_reader.get_namespaces() 
print(f'Namespaces: {namespaces}')
for ns in namespaces:
        print(f"Namespace: {ns} | Count: {str(zim_reader.get_namespaces_count(ns))}")

# Get the file main page

print(f"Main Page URL: {zim_reader.get_main_page_url()}")  


# Create a filled article

article = pyzim.ZimArticle(namespace='A', url = 'Monadical', title='Monadical', content=test_content, should_index = True)

print(article.longurl)
print(article.url)

# Create an empty article then fill it
article2 = pyzim.ZimArticle()

article2.content =  test_content
article2.url = "Monadical_SAS"
article2.title = "Monadical SAS"

# Fill an article from a read article

article3 = pyzim.ZimArticle()

article3.content =  read_article.content
article3.url = "Our_Einstein"
article3.title = "Our Einstein's bio"

# Create a redirect article

article4 = pyzim.ZimArticle()
article4.namespace = 'A'
article4.url = "Our_Einstein_redirect"
article4.title = "Redirect to Einstein"
article4.redirect_url = read_article.url



# Write the articles
import uuid
rnd_str = str(uuid.uuid1()) 

test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"

zim_creator = pyzim.ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',main_page = "welcome",index_language= "eng", min_chunk_size= 2048)

# Add article to zim file
zim_creator.add_article(article)
zim_creator.add_article(article2) 
zim_creator.add_article(article3)
zim_creator.add_article(article4) 
zim_creator.add_article(read_article)

# Write articles to zim file
zim_creator.finalise()

# Read written articles

zim_reader = pyzim.ZimReader(test_zim_file_path + '-' + rnd_str + '.zim')
zim_test_article_long_url = "A/Monadical"

written_article = zim_reader.get_article(zim_test_article_long_url)
redirect_article = zim_reader.get_article("A/Our_Einstein_redirect")
print(f"Is {redirect_article.longurl} a redirect: {redirect_article.is_redirect}")

# Get redirected Article
redirected = zim_reader.get_redirect_article(redirect_article)
print(redirected.longurl)

# Read written metadata by url

date_metadata = zim_reader.get_article("M/Date")
print(f"Date Metadata: {date_metadata.content}")

counter_metadata = zim_reader.get_article("M/Counter")
# Redirect articles are not counted
print(f"Counter Metadata: {counter_metadata.content}")

# Get all the file metadata as dict
metadata = zim_reader.get_metadata()

print(f"Metadata: {metadata}")

# Get the file checksum

print(f"File: {zim_reader.filename} \nChecksum: {zim_reader.get_checksum()}")

