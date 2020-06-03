# This file is part of python-libzim
# (see https://github.com/libzim/python-libzim)
#
# Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


# Write the article
import uuid

from libzim.writer import Article, Blob, Creator


class TestArticle(Article):
    def __init__(self, url, title, content):
        Article.__init__(self)
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
        return Blob(self.content)


# Create a TestArticle article

content = """<!DOCTYPE html>
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical</title>
                </head>
                <h1> ñññ Hello, it works ñññ </h1></html>"""

content2 = """<!DOCTYPE html>
                <html class="client-js">
                <head><meta charset="UTF-8">
                <title>Monadical 2</title>
                </head>
                <h1> ñññ Hello, it works 2 ñññ </h1></html>"""

article = TestArticle("Monadical_SAS", "Monadical", content)
article2 = TestArticle("Monadical_2", "Monadical 2", content2)

rnd_str = str(uuid.uuid1())
zim_file_path = f"kiwix-test-{rnd_str}.zim"

with Creator(zim_file_path, main_page="Monadical", index_language="eng", min_chunk_size=2048) as zc:
    zc.add_article(article)
    zc.add_article(article2)
    zc.update_metadata(
        creator="python-libzim",
        description="Created in python",
        name="Hola",
        publisher="Monadical",
        title="Test Zim",
    )
