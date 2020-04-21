import pytest
from pathlib import Path

DATA_DIR = Path(__file__).parent

from libzim.reader import File

@pytest.fixture
def reader_data():
    return (
        File(str(DATA_DIR/"wikipedia_es_physics_mini.zim")),
        {
            'filename': str(DATA_DIR/"wikipedia_es_physics_mini.zim"),
            'checksum': u"99ea7a5598c6040c4f50b8ac0653b703",
            'namespaces': u"-AIMX",
            'article_count': 22027,
            'main_page_url': u"A/index"
        }
    )


@pytest.fixture
def article_data():
    return {
        'url': u"A/Albert_Einstein",
        'title': u"Albert Einstein",
        'mimetype':u"text/html",
        'article_id': 663
    }


def test_zim_filename(reader_data):
    reader, data = reader_data
    for k, v in data.items():
        assert getattr(reader, k) == v

def test_zim_read(reader_data, article_data):
    reader, _ = reader_data
    article = reader.get_article(article_data['url'])

    assert article.longurl == article_data['url']
    assert article.title == article_data['title']
    assert article.url == article_data['url'][2:]
    assert article.mimetype == article_data['mimetype']

def test_get_article_by_id(reader_data, article_data):
    reader, _ = reader_data
    article = reader.get_article_by_id(article_data['article_id'])

    assert article.longurl == article_data['url']
    assert article.title == article_data['title']
    assert article.url == article_data['url'][2:]
    assert article.mimetype == article_data['mimetype']

def test_namespace_count(reader_data):
    reader, _ = reader_data
    namespaces = reader.namespaces
    num_articles = sum(reader.get_namespaces_count(ns) for ns in namespaces)
    assert reader.article_count == num_articles

def test_suggest(reader_data):
    reader, _ = reader_data
    results =  reader.suggest(u"Einstein")
    assert u"A/Albert_Einstein" in list(results)

def test_search(reader_data):
    reader, _ = reader_data
    results = reader.search(u"Einstein")
    assert len(list(results)) == 10
