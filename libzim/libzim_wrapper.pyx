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


cimport libzim.libzim_wrapper as clibzim
from cython.operator import dereference

from libc.stdint cimport uint64_t
from libcpp.string cimport string
from libcpp cimport bool
from libcpp.memory cimport shared_ptr, make_shared

import datetime

from cpython.ref cimport PyObject

#########################
#       ZimBlob         #
#########################

cdef class ZimBlob:
    cdef clibzim.Blob* c_blob
    cdef bytes ref_content

    def __cinit__(self, content):
        if isinstance(content, str):
            self.ref_content = content.encode('UTF-8')
        else:
            self.ref_content = content
        self.c_blob = new clibzim.Blob(<char *> self.ref_content, len(self.ref_content))

    def __dealloc__(self):
        if self.c_blob != NULL:
            del self.c_blob


#########################
#       ZimArticle      #
#########################

#------ Helper for pure virtual methods --------

cdef get_article_method_from_object(object obj, string method, int *error) with gil:
    try:
        func = getattr(obj, method.decode('UTF-8'))
    except AttributeError:
        error[0] = 1
        raise
    else:
        error[0] = 0
        return func

#------- ZimArticle pure virtual methods --------

cdef public api:
    string string_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a string"""
        func = get_article_method_from_object(obj, method, error)
        ret_str = func()
        return ret_str.encode('UTF-8')

    clibzim.Blob blob_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a Blob"""
        cdef ZimBlob blob

        func = get_article_method_from_object(obj, method, error)
        blob = func()
        return dereference(blob.c_blob)

    bool bool_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning a bool"""
        func = get_article_method_from_object(obj, method, error)
        return func()

    uint64_t int_cy_call_fct(object obj, string method, int *error) with gil:
        """Lookup and execute a pure virtual method on ZimArticle returning an int"""
        func = get_article_method_from_object(obj, method, error)
        return <uint64_t> func()

cdef class ZimCreator:
    """
    A class to represent a Zim Creator.

    Attributes
    ----------
    *c_creator : zim.ZimCreator
        a pointer to the C++ Creator object
    _finalized : bool
        flag if the creator was finalized
    """

    cdef clibzim.ZimCreatorWrapper *c_creator
    cdef bool _finalized

    def __cinit__(self, str filename, str main_page = "", str index_language = "eng", min_chunk_size = 2048):
        """Constructs a ZimCreator from parameters.
        Parameters
        ----------
        filename : str
            Zim file path
        main_page : str
            Zim file main page
        index_language : str
            Zim file index language (default eng)
        min_chunk_size : int
            Minimum chunk size (default 2048)
        """

        self.c_creator = clibzim.ZimCreatorWrapper.create(filename.encode("UTF-8"), main_page.encode("UTF-8"), index_language.encode("UTF-8"), min_chunk_size)
        self._finalized = False

    def __dealloc__(self):
        del self.c_creator

    def add_article(self, article not None):
        """Add a article to the Creator object.

        Parameters
        ----------
        article : ZimArticle
            The article to add to the file
        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """
        if self._finalized:
            raise RuntimeError("ZimCreator already finalized")

        # Make a shared pointer to ZimArticleWrapper from the ZimArticle object
        cdef shared_ptr[clibzim.ZimArticleWrapper] art = shared_ptr[clibzim.ZimArticleWrapper](
            new clibzim.ZimArticleWrapper(<PyObject*>article));
        with nogil:
            self.c_creator.addArticle(art)

    def finalize(self):
        """finalize and write added articles to the file.

        Raises
        ------
            RuntimeError
                If the ZimCreator was already finalized
        """
        if  self._finalized:
            raise RuntimeError("ZimCreator already finalized")
        with nogil:
            self.c_creator.finalize()
        self._finalized = True

