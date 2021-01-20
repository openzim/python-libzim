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


import uuid

from libzim.reader import Archive
from libzim.writer import Item, StringProvider, Creator


class TestItem(Item):
    def __init__(self, title, path, content):
        super().__init__()
        self.path = path
        self.title = title
        self.content = content

    def get_path(self):
        return self.path

    def get_title(self):
        return self.title

    def get_mimetype(self):
        return "text/html"

    def get_contentProvider(self):
        return StringProvider(self.content)


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

item = TestItem("Monadical_SAS", "Monadical", content)
item2 = TestItem("Monadical_2", "Monadical 2", content2)

zim_file_path = f"kiwix-test-{uuid.uuid1()}.zim"

print(f"Testing writer for {zim_file_path}")
with Creator(zim_file_path).configIndexing(True, "eng").configMinClusterSize(512) as zc:
    zc.setMainPath("Monadical")
    zc.add_item(item)
    zc.add_item(item2)
    for name, value in {
        "creator": "python-libzim",
        "description": "Created in python",
        "name": "Hola",
        "publisher": "Monadical",
        "title": "Test Zim",
    }.items():

        zc.add_metadata(name.title(), value.encode("UTF-8"))


print("Testing reader")
zim = Archive(zim_file_path)
entry = zim.get_entry_by_path("Monadical")
print(f"Main entry is at {zim.main_entry.get_item().path}")
print(f"Entry {entry.title} at {entry.path} is {entry.get_item().size}b:")
print(bytes(entry.get_item().content).decode("UTF-8"))
