""" libzim reader module

    - File to open and read ZIM files
    - Article are returned by File on get_article() and get_article_by_id()

    Usage:

    with File(pathlib.Path("myfile.zim")) as zf:
        article = zf.get_article(zf.main_page_url)
        print(f"Article {article.title} at {article.url} is {article.content.nbytes}b")
    """

# flake8: noqa
from .wrapper import FilePy as File
from .wrapper import ReadArticle as Article
