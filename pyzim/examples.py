import pyzim

content = '''<!DOCTYPE html> 
<html class="client-js">
<head><meta charset="UTF-8">
<title>Albert Einstein</title>
<h1> Hola Funciona </h1></html>'''


article = pyzim.ZimArticle(ns='A', url = 'Monadical', title='Monadical SAS', content=content.encode(), should_index = True)

import uuid

rnd_str = str(uuid.uuid1()) 

test_zim_file_path = "/opt/python-libzim/tests/kiwix-test"

zim_creator = pyzim.ZimCreator(test_zim_file_path + '-' + rnd_str + '.zim',"welcome","eng",2048)
zim_creator.add_article(article)

test_zim_reader = pyzim.ZimReader(test_zim_file_path + '-' + rnd_str + '.zim')

zim_test_article_long_url = "A/Hola"

written_article = test_zim_reader.get_article(zim_test_article_long_url)

