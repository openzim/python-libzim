import gc
from pathlib import Path

import pytest

from libzim.reader import File

DATA_DIR = Path(__file__).parent


ZIMFILES = [
    {
        "filename": DATA_DIR / "wikipedia_es_physics_mini.zim",
        "checksum": "99ea7a5598c6040c4f50b8ac0653b703",
        "namespaces": "-AIMX",
        "article_count": 22027,
        "main_page_url": "A/index",
    }
]


@pytest.fixture(params=ZIMFILES)
def zimdata(request):
    return request.param


@pytest.fixture
def reader(zimdata):
    return File(zimdata["filename"])


@pytest.fixture
def article_data():
    return {
        "url": "A/Albert_Einstein",
        "title": "Albert Einstein",
        "mimetype": "text/html",
        "article_id": 663,
        "size": 17343,
    }


def test_zim_filename(reader, zimdata):
    for k, v in zimdata.items():
        assert getattr(reader, k) == v
    assert isinstance(reader.filename, Path)


def test_zim_read(reader, article_data):
    article = reader.get_article(article_data["url"])

    assert article.longurl == article_data["url"]
    assert article.title == article_data["title"]
    assert article.url == article_data["url"][2:]
    assert article.mimetype == article_data["mimetype"]
    assert isinstance(article.content, memoryview)
    assert len(article.content) == article_data["size"]


def test_content_ref_keep(reader):
    """Get the memoryview on a content and loose the reference on the article.
       We try to load a lot of other articles to detect possible use of dandling pointer
    """
    content = None

    def get_content():
        nonlocal content
        article = reader.get_article("A/Albert_Einstein")
        assert isinstance(article.content, memoryview)
        content = article.content

    get_content()  # Now we have a content but no reference to the article.
    gc.collect()
    # Load a lot of content
    for i in range(0, reader.article_count, 2):
        article = reader.get_article_by_id(i)
        if not article.is_redirect:
            _ = article.content
    # Check everything is ok
    assert len(content) == 17343
    assert (
        bytes(content[:100])
        == b'<!DOCTYPE html>\n<html class="client-js"><head>\n  <meta charset="UTF-8">\n  <title>Albert Einstein</ti'  # noqa
    )


def test_get_article_by_id(reader, article_data):
    return
    article = reader.get_article_by_id(article_data["article_id"])

    assert article.longurl == article_data["url"]
    assert article.title == article_data["title"]
    assert article.url == article_data["url"][2:]
    assert article.mimetype == article_data["mimetype"]


def test_namespace_count(reader):
    namespaces = reader.namespaces
    num_articles = sum(reader.get_namespace_count(ns) for ns in namespaces)
    assert reader.article_count == num_articles


def test_suggest(reader):
    results = reader.suggest("Einstein")
    assert "A/Albert_Einstein" in list(results)


def test_search(reader):
    results = reader.search("Einstein")
    assert len(list(results)) == 10


def test_get_wrong_article(reader):
    with pytest.raises(IndexError):  # out of range
        reader.get_article_by_id(reader.article_count + 100)
    with pytest.raises(KeyError):
        reader.get_article("A/I_do_not_exists")


def test_redirects(reader):
    # we can access target article from a redirect one
    abundante = reader.get_article("A/Abundante")
    assert abundante.is_redirect
    target = abundante.get_redirect_article()
    assert target.longurl != abundante.longurl

    # we can't access a target on non-redirect articles
    assert target.is_redirect is False
    with pytest.raises(RuntimeError):
        target.get_redirect_article()
