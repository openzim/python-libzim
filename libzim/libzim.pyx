# This file is part of python-libzim
# (see https://github.com/libzim/python-libzim)
#
# Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>
# Copyright (c) 2020 Matthieu Gautier <mgautier@kymeria.fr>
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

# Make our libzim module a package by setting a __path__
# There is no real path here, but it will be passed to our module finder.
"""openZIM's file format library binding

- libzim.writer to create ZIM file with Creator
- libzim.reader to open ZIM file as Archive
- libzim.search to search on an Archive
- libzim.suggestion to retrieve suggestions on an Archive

https://openzim.org"""
__path__ = []

cimport zim

import datetime
import enum
import importlib
import importlib.abc
import os
import pathlib
import sys
import traceback
from types import ModuleType
from typing import Dict, Generator, Iterator, List, Set, Union
from uuid import UUID

from cpython.buffer cimport PyBUF_WRITABLE
from cpython.ref cimport PyObject

from cython.operator import preincrement

from libc.stdint cimport uint64_t
from libcpp cimport bool
from libcpp.map cimport map
from libcpp.memory cimport shared_ptr
from libcpp.string cimport string
from libcpp.utility cimport move

pybool = type(True)
pyint = type(1)

def create_module(name, doc, members):
    """Create/define a module for name and docstring, populated by members"""
    module = ModuleType(name, doc)
    _all = []
    for obj in members:
        if isinstance(obj, tuple):
            name = obj[0]
            obj = obj[1]
        else:
            name = obj.__name__
        setattr(module, name, obj)
        _all.append(name)
    module.__all__ = _all
    sys.modules[name] = module
    return module

###############################################################################
#   Public API to be called from C++ side                                     #
###############################################################################

# This calls a python method and returns a python object.
cdef object call_method(object obj, string method):
    func = getattr(obj, method.decode('UTF-8'))
    return func()

# Define methods calling a python method and converting the resulting python
# object to the correct cpp type.
# Will be used by cpp side to call python method.
cdef public api:
    string string_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a string"""
        try:
            ret_str = call_method(obj, method)
            return ret_str.encode('UTF-8')
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')
        return b""

    zim.Blob blob_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a Blob"""
        cdef WritingBlob blob

        try:
            blob = call_method(obj, method)
            if blob is None:
                raise RuntimeError("Blob is none")
            return move(blob.c_blob)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return move(zim.Blob())

    zim.ContentProvider* contentprovider_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning a ContentProvider"""
        try:
            contentProvider = call_method(obj, method)
            if not contentProvider:
                raise RuntimeError("ContentProvider is None")
            return new zim.ContentProviderWrapper(<PyObject*>contentProvider)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return NULL

    # currently have no virtual method returning a bool (was should_index/compress)
    # bool bool_cy_call_fct(object obj, string method, string *error) with gil:
    #     """Lookup and execute a pure virtual method on object returning a bool"""
    #     try:
    #         func = getattr(obj, method.decode('UTF-8'))
    #         return func()
    #     except Exception as e:
    #         error[0] = traceback.format_exc().encode('UTF-8')
    #     return False

    uint64_t int_cy_call_fct(object obj, string method, string *error) with gil:
        """Lookup and execute a pure virtual method on object returning an int"""
        try:
            return <uint64_t> call_method(obj, method)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return 0

    map[zim.HintKeys, uint64_t] convertToCppHints(dict hintsDict):
        """C++ Hints from Python dict"""
        cdef map[zim.HintKeys, uint64_t] ret;
        for key, value in hintsDict.items():
            ret[key.value] = <uint64_t>value
        return ret

    map[zim.HintKeys, uint64_t] hints_cy_call_fct(object obj, string method, string* error) with gil:
        """Lookup and execute a pure virtual method on object returning Hints"""
        cdef map[zim.HintKeys, uint64_t] ret;
        try:
            func = getattr(obj, method.decode('UTF-8'))
            hintsDict = {k: pybool(v) for k, v in func().items() if isinstance(k, Hint)}
            return convertToCppHints(hintsDict)
        except Exception as e:
            error[0] = traceback.format_exc().encode('UTF-8')

        return ret


###############################################################################
#   Creator module                                                            #
###############################################################################

writer_module_name = f"{__name__}.writer"

cdef class WritingBlob:
    __module__ = writer_module_name
    cdef zim.Blob c_blob
    cdef bytes ref_content

    def __cinit__(self, content: Union[str, bytes]):
        if isinstance(content, str):
            self.ref_content = content.encode('UTF-8')
        else:
            self.ref_content = content
        self.c_blob = move(zim.Blob(<char *> self.ref_content, len(self.ref_content)))

    def size(self):
        return self.c_blob.size()



class Compression(enum.Enum):
    """Compression algorithms available to create ZIM files"""
    __module__ = writer_module_name
    # We don't care of the exact value. The function comp_from_int will do the right
    # conversion to zim::Compression
    none = 0
    lzma = 1
    zstd = 2


class Hint(enum.Enum):
    __module__ = writer_module_name
    COMPRESS = zim.HintKeys.COMPRESS
    FRONT_ARTICLE = zim.HintKeys.FRONT_ARTICLE



cdef class _Creator:
    """ZIM Creator

        Attributes
        ----------
        *c_creator : zim.ZimCreator
            a pointer to the C++ Creator object
        _filename: pathlib.Path
            path to create the ZIM file at
        _started : bool
            flag if the creator has started"""
    __module__ = writer_module_name

    cdef zim.ZimCreator c_creator
    cdef object _filename
    cdef object _started

    def __cinit__(self, object filename: pathlib.Path, *args, **kwargs):
        self._filename = pathlib.Path(filename)
        self._started = False
        # fail early if destination is not writable
        parent = self._filename.expanduser().resolve().parent
        if not os.access(parent, mode=os.W_OK, effective_ids=(os.access in os.supports_effective_ids)):
            raise IOError(f"Unable to write ZIM file at {self._filename}")

    def __init__(self, filename: pathlib.Path):
        """Constructs a Creator for a ZIM file at path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file"""
        pass

    def config_verbose(self, bool verbose: bool) -> Creator:
        """Set creator verbosity (inside libzim). Default is off"""
        if self._started:
            raise RuntimeError("Creator started")
        self.c_creator.configVerbose(verbose)
        return self

    def config_compression(self, compression: Compression) -> Creator:
        """Set compression algorithm to use. Check libzim for default

            Fall 2021 default: zstd"""
        if self._started:
            raise RuntimeError("Creator started")
        self.c_creator.configCompression(zim.comp_from_int(compression.value))
        return self

    def config_clustersize(self, int size: pyint) -> Creator:
        """Set size of created clusters. Check libzim for default

            libzim will store at most this value per cluster before creating
            another one.
            Fall 2021 default: 2Mib"""
        if self._started:
            raise RuntimeError("Creator started")
        self.c_creator.configClusterSize(size)
        return self

    def config_indexing(self, bool indexing: bool, str language: str) -> Creator:
        """Configure fulltext indexing feature

            indexing: whether to create a full-text index of the content
            language: language (ISO-639-3 code) to assume content in during indexation"""
        if self._started:
            raise RuntimeError("Creator started")
        self.c_creator.configIndexing(indexing, language.encode('UTF-8'))
        return self

    def config_nbworkers(self, int nbWorkers: pyint) -> Creator:
        """Number of thread to use for internal worker"""
        if self._started:
            raise RuntimeError("Creator started")
        self.c_creator.configNbWorkers(nbWorkers)
        return self

    def set_mainpath(self, str mainPath: str) -> Creator:
        """Set path of the main entry"""
        self.c_creator.setMainPath(mainPath.encode('UTF-8'))
        return self

    def add_illustration(self, int size: pyint, content: bytes):
        """Add a PNG illustration to Archive

            https://wiki.openzim.org/wiki/Metadata

            Raises
            ------
                RuntimeError
                    If an Illustration exists with the same size"""
        cdef string _content = content
        self.c_creator.addIllustration(size, _content)

#    def set_uuid(self, uuid) -> Creator:
#        self.c_creator.setUuid(uuid)

    def add_item(self, writer_item not None: BaseWritingItem):
        """Add an item to the Creator object.

            Parameters
            ----------
            item : WriterItem
                The item to add to the file
            Raises
            ------
                RuntimeError
                    If an Item exists with the same path
                RuntimeError
                    If the ZimCreator was already finalized"""
        if not self._started:
            raise RuntimeError("Creator not started")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object
        cdef shared_ptr[zim.WriterItem] item = shared_ptr[zim.WriterItem](
            new zim.WriterItemWrapper(<PyObject*>writer_item));
        with nogil:
            self.c_creator.addItem(item)

    def add_metadata(self, str name: str, bytes content: bytes, str mimetype: str):
        """Add metadata entry to Archive

            https://wiki.openzim.org/wiki/Metadata

            Raises
            ------
                RuntimeError
                    If a Metadata exists with the same name"""
        if not self._started:
            raise RuntimeError("Creator not started")

        cdef string _name = name.encode('UTF-8')
        cdef string _content = content
        cdef string _mimetype = mimetype.encode('UTF-8')
        with nogil:
            self.c_creator.addMetadata(_name, _content, _mimetype)

    def add_redirection(self, str path: str, str title: str, str targetPath: str, dict hints: Dict[Hint, pyint]):
        """Add redirection entry to Archive

            https://wiki.openzim.org/wiki/ZIM_file_format#Redirect_Entry

            Raises
            ------
                RuntimeError
                    If a Rediction exists with the same path
            """
        if not self._started:
            raise RuntimeError("Creator not started")

        cdef string _path = path.encode('UTF-8')
        cdef string _title = title.encode('UTF-8')
        cdef string _targetPath = targetPath.encode('UTF-8')
        cdef map[zim.HintKeys, uint64_t] _hints = convertToCppHints(hints)
        with nogil:
            self.c_creator.addRedirection(_path, _title, _targetPath, _hints)

    def __enter__(self):
        cdef string _path = str(self._filename).encode('UTF-8')
        with nogil:
            self.c_creator.startZimCreation(_path)
        self._started = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if True or exc_type is None:
            with nogil:
                self.c_creator.finishZimCreation()
        self._started = False

    @property
    def filename(self) -> pathlib.Path:
        return self._filename

class ContentProvider:
    __module__ = writer_module_name
    def __init__(self):
        self.generator = None

    def get_size(self) -> pyint:
        """Size of get_data's result in bytes"""
        raise NotImplementedError("get_size must be implemented.")

    def feed(self) -> WritingBlob:
        """Blob(s) containing the complete content of the article.
        Must return an empty blob to tell writer no more content has to be written.
        Sum(size(blobs)) must be equals to `self.get_size()`
        """
        if self.generator is None:
            self.generator = self.gen_blob()

        try:
            # We have to keep a ref to _blob to be sure gc do not del it while cpp is
            # using it
            self._blob = next(self.generator)
        except StopIteration:
            self._blob = WritingBlob("")

        return self._blob

    def gen_blob(self) -> Generator[WritingBlob, None, None]:
        """Generator yielding blobs for the content of the article"""
        raise NotImplementedError("gen_blob (ro feed) must be implemented")


class StringProvider(ContentProvider):
    """ContentProvider for a single encoded-or-not UTF-8 string"""
    __module__ = writer_module_name
    def __init__(self, content: Union[str, bytes]):
        super().__init__()
        self.content = content.encode("UTF-8") if isinstance(content, str) else content

    def get_size(self) -> pyint:
        return len(self.content)

    def gen_blob(self) -> Generator[WritingBlob, None, None]:
        yield WritingBlob(self.content)


class FileProvider(ContentProvider):
    """ContentProvider for a file using its local path"""
    __module__ = writer_module_name
    def __init__(self, filepath: Union[pathlib.Path, str]):
        super().__init__()
        self.filepath = filepath
        self.size = os.path.getsize(self.filepath)

    def get_size(self) -> pyint:
        return self.size

    def gen_blob(self) -> Generator[WritingBlob, None, None]:
        bsize = 1048576  # 1MiB chunk
        with open(self.filepath, "rb") as fh:
            res = fh.read(bsize)
            while res:
                yield WritingBlob(res)
                res = fh.read(bsize)


class BaseWritingItem:
    """Item stub to override

    Pass a subclass of it to Creator.add_item()"""
    __module__ = writer_module_name

    def __init__(self):
        self._blob = None

    def get_path(self) -> str:
        """Full path of item"""
        raise NotImplementedError("get_path must be implemented.")

    def get_title(self) -> str:
        """Item title. Might be indexed and used in suggestions"""
        raise NotImplementedError("get_title must be implemented.")

    def get_mimetype(self) -> str:
        """MIME-type of the item's content."""
        raise NotImplementedError("get_mimetype must be implemented.")

    def get_contentprovider(self) -> ContentProvider:
        """ContentProvider containing the complete content of the item"""
        raise NotImplementedError("get_contentprovider must be implemented.")

    def get_hints(self) -> Dict[Hint, pyint]:
        """Dict of Hint: value informing Creator how to handle this item"""
        raise NotImplementedError("get_hints must be implemented.")

    def __repr__(self) -> str:
        return (
            f"{self.__class__.__name__}(path={self.get_path()}, "
            f"title={self.get_title()})"
        )


def pascalize(keyword: str):
    """Converts python case to pascal case.

    example: long_description -> LongDescription"""
    return "".join(keyword.title().split("_"))


class Creator(_Creator):
    __module__ = writer_module_name
    def config_compression(self, compression: Compression):
        if not isinstance(compression, Compression):
            compression = getattr(Compression, compression.lower())
        return super().config_compression(compression)

    def add_metadata(
        self, name: str, content: Union[str, bytes, datetime.date, datetime.datetime],
        mimetype: str = "text/plain;charset=UTF-8"
    ):
        name = pascalize(name)
        if name == "Date" and isinstance(content, (datetime.date, datetime.datetime)):
            content = content.strftime("%Y-%m-%d").encode("UTF-8")
        if isinstance(content, str):
            content = content.encode("UTF-8")
        super().add_metadata(name=name, content=content, mimetype=mimetype)

    def __repr__(self) -> str:
        return f"Creator(filename={self.filename})"

writer_module_doc = """libzim writer module
- Creator to create ZIM files
- Item to store ZIM articles metadata
- ContentProvider to store an Item's content
- Blob to store actual content
- StringProvider to store an Item's content from a string
- FileProvider to store an Item's content from a file path
- Compression to select the algorithm to compress ZIM archive with

Usage:
with Creator(pathlib.Path("myfile.zim")) as creator:
    creator.config_verbose(False)
    creator.add_metadata("Name", b"my name")
    # example
    creator.add_item(MyItemSubclass(path, title, mimetype, content)
    creator.set_mainpath(path)"""
writer_public_objects = [
    Creator,
    Compression,
    ('Blob', WritingBlob),
    Hint,
    ('Item', BaseWritingItem),
    ContentProvider,
    FileProvider,
    StringProvider,
    pascalize
]
writer = create_module(writer_module_name, writer_module_doc, writer_public_objects)


###############################################################################
#   Reader module                                                             #
###############################################################################

reader_module_name = f"{__name__}.reader"
cdef Py_ssize_t itemsize = 1

cdef class ReadingBlob:
    __module__ = reader_module_name
    cdef zim.Blob c_blob
    cdef Py_ssize_t size
    cdef int view_count

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_blob(zim.Blob blob):
        """Creates a python Blob from a C++ Blob (zim::) -> Blob

            Parameters
            ----------
            blob : Blob
                A C++ Entry
            Returns
            ------
            Blob
                Casted blob"""
        cdef ReadingBlob rblob = ReadingBlob()
        rblob.c_blob = move(blob)
        rblob.size = rblob.c_blob.size()
        rblob.view_count = 0
        return rblob

    def __dealloc__(self):
        if self.view_count:
            raise RuntimeError("Blob has views")

    def __getbuffer__(self, Py_buffer *buffer, int flags):
        if flags&PyBUF_WRITABLE:
            raise BufferError("Cannot create writable memoryview on readonly data")
        buffer.obj = self
        buffer.buf = <void*>self.c_blob.data()
        buffer.len = self.size
        buffer.readonly = 1
        buffer.format = 'c'
        buffer.internal = NULL                  # see References
        buffer.itemsize = itemsize
        buffer.ndim = 1
        buffer.shape = &self.size
        buffer.strides = &itemsize
        buffer.suboffsets = NULL                # for pointer arrays only

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer *buffer):
        self.view_count -= 1


cdef class Entry:
    """Entry in a ZIM archive

        Attributes
        ----------
        *c_entry : Entry (zim::)
            a pointer to the C++ entry object"""
    __module__ = reader_module_name
    cdef zim.Entry c_entry

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_entry(zim.Entry ent):
        """Creates a python Entry from a C++ Entry (zim::) -> Entry

            Parameters
            ----------
            ent : Entry
                A C++ Entry
            Returns
            ------
            Entry
                Casted entry"""
        cdef Entry entry = Entry()
        entry.c_entry = move(ent)
        return entry

    @property
    def title(self) -> str:
        return self.c_entry.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        return self.c_entry.getPath().decode("UTF-8", "strict")

    @property
    def _index(self) -> pyint:
        """Internal index in Archive"""
        return self.c_entry.getIndex()

    @property
    def is_redirect(self) -> pybool:
        """Whether entry is a redirect"""
        return self.c_entry.isRedirect()

    def get_redirect_entry(self) -> Entry:
        """Target of this entry, if a redirect"""
        cdef zim.Entry entry = move(self.c_entry.getRedirectEntry())
        return Entry.from_entry(move(entry))

    def get_item(self) -> Item:
        cdef zim.Item item = move(self.c_entry.getItem(True))
        return Item.from_item(move(item))

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(url={self.path}, title={self.title})"

cdef class Item:
    """Item in a ZIM archive

        Attributes
        ----------
        *c_entry : Entry (zim::)
            a pointer to the C++ entry object"""
    __module__ = reader_module_name
    cdef zim.Item c_item
    cdef ReadingBlob _blob
    cdef bool _haveBlob

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_item(zim.Item _item):
        """Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            _item : Item
                A C++ Item
            Returns
            ------
            Item
                Casted item"""
        cdef Item item = Item()
        item.c_item = move(_item)
        return item

    @property
    def title(self) -> str:
        return self.c_item.getTitle().decode('UTF-8')

    @property
    def path(self) -> str:
        return self.c_item.getPath().decode("UTF-8", "strict")

    @property
    def content(self) -> memoryview:
        if not self._haveBlob:
            self._blob = ReadingBlob.from_blob(move(self.c_item.getData(<int> 0)))
            self._haveBlob = True
        return memoryview(self._blob)

    @property
    def mimetype(self) -> str:
        return self.c_item.getMimetype().decode('UTF-8')

    @property
    def _index(self) -> pyint:
        """Internal index in Archive"""
        return self.c_item.getIndex()

    @property
    def size(self) -> pyint:
        return self.c_item.getSize()

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(url={self.path}, title={self.title})"


cdef class Archive:
    """ZIM Archive Reader

        Attributes
        ----------
        *c_archive : Archive
            a pointer to a C++ Archive object
        _filename : pathlib.Path
            the file name of the Archive Reader object"""

    __module__ = reader_module_name
    cdef zim.Archive c_archive
    cdef object _filename

    def __cinit__(self, object filename: pathlib.Path):
        """Constructs an Archive from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file"""

        self.c_archive = move(zim.Archive(str(filename).encode('UTF-8')))
        self._filename = pathlib.Path(self.c_archive.getFilename().decode("UTF-8", "strict"))

    def __eq__(self, other) -> pybool:
        if Archive not in type(self).mro() or Archive not in type(other).mro():
            return False
        try:
            return self.filename.expanduser().resolve() == other.filename.expanduser().resolve()
        except Exception:
            return False

    @property
    def filename(self) -> pathlib.Path:
        return self._filename

    @property
    def filesize(self) -> pyint:
        """Total size of ZIM file (or files if split"""
        return self.c_archive.getFilesize()

    def has_entry_by_path(self, path: str) -> pybool:
        """Whether Archive has an entry with this path"""
        return self.c_archive.hasEntryByPath(<string>path.encode('UTF-8'))

    def get_entry_by_path(self, path: str) -> Entry:
        """Entry from a path -> Entry

            Parameters
            ----------
            path : str
                The path of the article
            Returns
            -------
            Entry
                The Entry object
            Raises
            ------
                KeyError
                    If an entry with the provided path is not found in the archive"""
        cdef zim.Entry entry
        try:
            entry = move(self.c_archive.getEntryByPath(<string>path.encode('UTF-8')))
        except RuntimeError as e:
            raise KeyError(str(e))
        return Entry.from_entry(move(entry))

    def has_entry_by_title(self, title: str) -> pybool:
        """Whether Archive has en entry with this title

            Uses get_entry_by_title() so it's specificities apply as well"""
        return self.c_archive.hasEntryByTitle(<string>title.encode('UTF-8'))

    def get_entry_by_title(self, title: str) -> Entry:
        """Entry from a title -> Entry

            If ZIM doesn't contain a listing/titleOrdered/v1 entry (most likely
            because if was created without any FRONT_ARTICLE) then this yields results
            for matching path if the title was not set at creation time.
            Otherwise raises KeyError.

            Parameters
            ----------
            title : str
                The title of the article
            Returns
            -------
            Entry
                The first Entry object matching the title
            Raises
            ------
                KeyError
                    If an entry with the provided title is not found in the archive"""
        cdef zim.Entry entry
        try:
            entry = move(self.c_archive.getEntryByTitle(<string>title.encode('UTF-8')))
        except RuntimeError as e:
            raise KeyError(str(e))
        return Entry.from_entry(move(entry))

    @property
    def metadata_keys(self) -> List[str]:
        """List of Metadata keys present in this archive"""
        return [key.decode("UTF-8", "strict") for key in self.c_archive.getMetadataKeys()]

    def get_metadata_item(self, name: str) -> Item:
        """A Metadata's Item"""
        cdef zim.Item item = move(self.c_archive.getMetadataItem(name.encode('UTF-8')))
        return Item.from_item(move(item))

    def get_metadata(self, name: str) -> bytes:
        """A Metadata's content -> bytes

            Parameters
            ----------
            name: str
                name/path of the Metadata Entry
            Returns
            -------
            bytes
                Metadata entry's content. Can be of any type."""
        return bytes(self.c_archive.getMetadata(name.encode('UTF-8')))

    def _get_entry_by_id(self, entry_id: pyint) -> Entry:
        """Entry from an entry Id"""
        cdef zim.Entry entry = move(self.c_archive.getEntryByPath(<zim.entry_index_type>entry_id))
        return Entry.from_entry(move(entry))

    @property
    def has_main_entry(self) -> pybool:
        """Whether Archive has a Main Entry set"""
        return self.c_archive.hasMainEntry()

    @property
    def main_entry(self) -> Entry:
        """Main Entry of the Archive"""
        return Entry.from_entry(move(self.c_archive.getMainEntry()))

    @property
    def uuid(self) -> UUID:
        """Archive UUID"""
        return UUID(self.c_archive.getUuid().hex())

    @property
    def has_new_namespace_scheme(self) -> pybool:
        """Whether Archive is using new “namespaceless” namespace scheme"""
        return self.c_archive.hasNewNamespaceScheme()

    @property
    def is_multipart(self) -> pybool:
        """Whether Archive is multipart (split over multiple files)"""
        return self.c_archive.isMultiPart()

    @property
    def has_fulltext_index(self) -> pybool:
        """Whether Archive includes a full-text index"""
        return self.c_archive.hasFulltextIndex()

    @property
    def has_title_index(self) -> pybool:
        """Whether Archive includes a Title index"""
        return self.c_archive.hasTitleIndex()

    @property
    def has_checksum(self) -> str:
        """Whether Archive includes a checksum of its content"""
        return self.c_archive.hasChecksum()

    @property
    def checksum(self) -> str:
        """Archive's checksum"""
        return self.c_archive.getChecksum().decode("UTF-8", "strict")

    def check(self) -> pybool:
        """Whether Archive has a checksum and file verifies it"""
        return self.c_archive.check()

    @property
    def entry_count(self) -> pyint:
        """Number of user entries in Archive

            If Archive doesn't support “user entries”
            then this returns `all_entry_count`"""
        return self.c_archive.getEntryCount()

    @property
    def all_entry_count(self) -> pyint:
        """Number of entries in Archive.

            Total number of entries in the archive, including internal entries
            created by libzim itself, metadata, indexes, etc."""
        return self.c_archive.getAllEntryCount()

    @property
    def article_count(self) -> pyint:
        """Number of “articles” in the Archive

            If Archive has_new_namespace_scheme then this is the
            number of Entry with “FRONT_ARTICLE” Hint.

            Otherwise, this is the number or entries in “A” namespace.

            Note: a few ZIM created during transition might have new scheme but no
            listing, resulting in this returning all entries."""
        return self.c_archive.getArticleCount()

    def get_illustration_sizes(self) -> Set[pyint]:
        """Sizes for which an illustration is available (@1 scale only)"""
        return self.c_archive.getIllustrationSizes()

    def has_illustration(self, size: pyint = None) -> pybool:
        """Whether Archive has an illustration metadata for this size"""
        if size is not None:
            return self.c_archive.hasIllustration(size)
        return self.c_archive.hasIllustration()

    def get_illustration_item(self, size: pyint = None) -> Item:
        """Illustration Metadata Item for this size"""
        try:
            if size is not None:
                return Item.from_item(move(self.c_archive.getIllustrationItem(size)))
            return Item.from_item(move(self.c_archive.getIllustrationItem()))
        except RuntimeError as e:
            raise KeyError(str(e))

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(filename={self.filename})"

reader_module_doc = """libzim reader module

- Archive to open and read ZIM files (gives access to all `Entry`)
- Entry knows about redirections, exposes path and title and gives access to `Item`
- Item holds the content and metadata

Usage:

with Archive(fpath) as zim:
    entry = zim.get_entry_by_path(zim.main_entry.path)
    print(f"Article {entry.title} at {entry.path} is "
          f"{entry.get_item().content.nbytes}b")"""
reader_public_objects = [
    Archive,
    Entry,
    Item,
]
reader = create_module(reader_module_name, reader_module_doc, reader_public_objects)


###############################################################################
#   Search module                                                             #
###############################################################################

search_module_name = f"{__name__}.search"

cdef class Query:
    """ZIM agnostic Query-builder to use with a Searcher"""
    __module__ = search_module_name
    cdef zim.Query c_query

    def set_query(self, query: str):
        self.c_query.setQuery(query.encode('UTF-8'))
        return self


cdef class SearchResultSet:
    """Iterator over a Search result: entry paths"""
    __module__ = search_module_name
    cdef zim.SearchResultSet c_resultset

    @staticmethod
    cdef from_resultset(zim.SearchResultSet _resultset):
        cdef SearchResultSet resultset = SearchResultSet()
        resultset.c_resultset = move(_resultset)
        return resultset

    def __iter__(self) -> Iterator[str]:
        """Entry paths found in Archive for Search"""
        cdef zim.SearchIterator current = self.c_resultset.begin()
        cdef zim.SearchIterator end = self.c_resultset.end()
        while current != end:
            yield current.getPath().decode('UTF-8')
            preincrement(current)

cdef class Search:
    """Search request over a ZIM Archive"""
    __module__ = search_module_name
    cdef zim.Search c_search

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_search(zim.Search _search):
        """Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            _item : Item
                A C++ Item
            Returns
            ------
            Item
                Casted item"""
        cdef Search search = Search()
        search.c_search = move(_search)
        return search

    def getEstimatedMatches(self) -> pyint:
        """Estimated number of results in Archive for the search"""
        return self.c_search.getEstimatedMatches()

    def getResults(self, start: pyint, count: pyint) -> SearchResultSet:
        """Iterator over Entry paths found in Archive for the search"""
        return SearchResultSet.from_resultset(move(self.c_search.getResults(start, count)))


cdef class Searcher:
    """ZIM Archive Searcher

        Attributes
        ----------
        *c_archive : Searcher
            a pointer to a C++ Searcher object"""
    __module__ = search_module_name

    cdef zim.Searcher c_searcher

    def __cinit__(self, object archive: Archive):
        """Constructs an Archive from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file"""

        self.c_searcher = move(zim.Searcher(archive.c_archive))

    def search(self, object query: Query) -> Search:
        """Search object for a query of this Searcher's ZIM Archive"""
        return Search.from_search(move(self.c_searcher.search(query.c_query)))

search_module_doc = """libzim search module

- Query to prepare a query from a string
- Searcher to perform a search over a libzim.reader.Archive

Usage:

archive = libzim.reader.Archive(fpath)
searcher = Searcher(archive)
query = Query().setQuery("foo")
search = searcher.search(query)
for path in search.getResult(10, 10) # get result from 10 to 20 (10 results)
    print(path, archive.get_entry_by_path(path).title)"""
search_public_objects = [
    Searcher,
    Query
]
search = create_module(search_module_name, search_module_doc, search_public_objects)


###############################################################################
#   Suggestion module                                                         #
###############################################################################

suggestion_module_name = f"{__name__}.suggestion"

cdef class SuggestionResultSet:
    """Iterator over a SuggestionSearch result: entry paths"""
    __module__ = suggestion_module_name
    cdef zim.SuggestionResultSet c_resultset

    @staticmethod
    cdef from_resultset(zim.SuggestionResultSet _resultset):
        cdef SuggestionResultSet resultset = SuggestionResultSet()
        resultset.c_resultset = move(_resultset)
        return resultset

    def __iter__(self) -> Iterator[str]:
        """Entry paths found in Archive for SuggestionSearch"""
        cdef zim.SuggestionIterator current = self.c_resultset.begin()
        cdef zim.SuggestionIterator end = self.c_resultset.end()
        while current != end:
            yield current.getSuggestionItem().getPath().decode('UTF-8')
            preincrement(current)

cdef class SuggestionSearch:
    __module__ = suggestion_module_name
    cdef zim.SuggestionSearch c_search

    # Factory functions - Currently Cython can't use classmethods
    @staticmethod
    cdef from_search(zim.SuggestionSearch _search):
        """Creates a python ReadArticle from a C++ Article (zim::) -> ReadArticle

            Parameters
            ----------
            _item : Item
                A C++ Item
            Returns
            ------
            Item
                Casted item"""
        cdef SuggestionSearch search = SuggestionSearch()
        search.c_search = move(_search)
        return search

    def getEstimatedMatches(self) -> pyint:
        """Estimated number of results in Archive for the suggestion search"""
        return self.c_search.getEstimatedMatches()

    def getResults(self, start: pyint, count: pyint) -> SuggestionResultSet:
        """Iterator over Entry paths found in Archive for the suggestion search"""
        return SuggestionResultSet.from_resultset(move(self.c_search.getResults(start, count)))


cdef class SuggestionSearcher:
    """ZIM Archive SuggestionSearcher

        Attributes
        ----------
        *c_archive : Searcher
            a pointer to a C++ Searcher object"""
    __module__ = suggestion_module_name

    cdef zim.SuggestionSearcher c_searcher

    def __cinit__(self, object archive: Archive):
        """Constructs an Archive from full zim file path

            Parameters
            ----------
            filename : pathlib.Path
                Full path to a zim file"""

        self.c_searcher = move(zim.SuggestionSearcher(archive.c_archive))

    def suggest(self, query: str) -> SuggestionSearch:
        """SuggestionSearch object for a query of this SuggestionSearcher's ZIM Archive"""
        return SuggestionSearch.from_search(move(self.c_searcher.suggest(query.encode('UTF-8'))))

suggestion_module_doc = """libzim suggestion module

- SuggestionSearcher to perform a suggestion search over a libzim.reader.Archive

Usage:

archive = Archive(fpath)
suggestion_searcher = SuggestionSearcher(archive)
suggestions = suggestion_searcher.suggest("foo")
for path in suggestion.getResult(10, 10) # get result from 10 to 20 (10 results)
    print(path, archive.get_entry_by_path(path).title)"""
suggestion_public_objects = [
    SuggestionSearcher
]
suggestion = create_module(suggestion_module_name, suggestion_module_doc, suggestion_public_objects)



class ModuleLoader(importlib.abc.Loader):
    # Create our module. Easy, just return the created module
    @staticmethod
    def create_module(spec):
        return {
            'libzim.writer': writer,
            'libzim.reader': reader,
            'libzim.search': search,
            'libzim.suggestion': suggestion
        }.get(spec.name, None)

    @staticmethod
    def exec_module(module):
        # Nothing to execute for our already existing module.
        # But we need to define exec_module to tell python not use the legacy import system.
        pass

class ModuleFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path, target=None):
        if fullname.startswith("libzim."):
            return importlib.machinery.ModuleSpec(fullname, ModuleLoader)
        # This is not our problem, let import mechanism continue
        return None

# register finder for our submodules
sys.meta_path.insert(0, ModuleFinder())

__all__ = ["writer", "reader", "search", "suggestion"]

