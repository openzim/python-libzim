# test files https://wiki.kiwix.org/wiki/Content_in_all_languages

import os,sys,inspect
current_dir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)

import pyzim


def main():
    zim_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
    f = pyzim.File(zim_path.encode())

    print 'Number of articles: ' + str(f.get_article_count())
    namespaces = f.get_namespaces() 
    print 'Namespaces: ' + namespaces
    for ns in namespaces:
        print 'Namespaces count ' + ns + ': '  + str(f.get_namespaces_count(ord(ns)))


    print 'Main Page URL: ' +  f.get_main_page_url()

    article = f.get_article(b"/A/Albert_Einstein")

    content = article.content()

    print(content[:200])


    # Creator test
    creator = pyzim.Creator(True)
    creator.zim_creation('hola.zim',True,"eng",2048)
    # Add article
    creator.add_article(article)
    creator.add_art()
    creator.zim_finalise()

    # Read created zim file
    created_zim_path = "/opt/python-libzim/hola.zim"
    f = pyzim.File(created_zim_path.encode()) 

    print 'Number of articles: ' + str(f.get_article_count())
    namespaces = f.get_namespaces() 
    print 'Namespaces: ' + namespaces
    for ns in namespaces:
        print 'Namespaces count ' + ns + ': '  + str(f.get_namespaces_count(ord(ns)))


    print 'Main Page URL: ' +  f.get_main_page_url()

    article = f.get_article(b"/A/Hola")
    print 'Long Url: ' + article.longurl()
    print article.url()
    #article = f.get_article(b"/A/Albert_Einstein")

    content = article.content()

    print(content[:200])



if __name__ == "__main__":
    main()



