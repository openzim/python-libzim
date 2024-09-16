/*
 * This file is part of python-libzim
 * (see https://github.com/libzim/python-libzim)
 *
 * Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>
 * Copyright (c) 2020 Matthieu Gautier <mgautier@kymeria.fr>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <Python.h>
#include "libwrapper.h"

#include "libzim_api.h"

#include <cstdlib>
#include <iostream>
#include <zim/blob.h>
#include <zim/writer/creator.h>

ObjWrapper::ObjWrapper(PyObject *obj)
    : m_obj(obj)
{
  if (import_libzim())
  {
    std::cerr << "Error executing import_libzim!\n";
    throw std::runtime_error("Error executing import_libzim");
  }
  Py_XINCREF(m_obj);
}

ObjWrapper::ObjWrapper(ObjWrapper &&other)
    : m_obj(other.m_obj)
{
  other.m_obj = nullptr;
}

ObjWrapper &ObjWrapper::operator=(ObjWrapper &&other)
{
  m_obj = other.m_obj;
  other.m_obj = nullptr;
  return *this;
}

ObjWrapper::~ObjWrapper()
{
  // We must decrement the ref of the python object.
  if (m_obj != nullptr)
  {
    PyGILState_STATE gstate;
    gstate = PyGILState_Ensure();
    Py_XDECREF(this->m_obj);
    PyGILState_Release(gstate);
  }
}

// Just call the right (regarding the output) method.
// No check or error handling.
template <typename Output>
Output _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error);

template <>
bool _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return bool_cy_call_fct(obj, methodName, &error);
}

template <>
std::string _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return string_cy_call_fct(obj, methodName, &error);
}

template <>
uint64_t _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return uint64_cy_call_fct(obj, methodName, &error);
}

template <>
uint32_t _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return uint32_cy_call_fct(obj, methodName, &error);
}

template <>
zim::Blob _call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return blob_cy_call_fct(obj, methodName, &error);
}

template <>
std::unique_ptr<zim::writer::ContentProvider>
_call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return std::unique_ptr<zim::writer::ContentProvider>(contentprovider_cy_call_fct(obj, methodName, &error));
}

template <>
std::shared_ptr<zim::writer::IndexData>
_call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return std::shared_ptr<zim::writer::IndexData>(indexdata_cy_call_fct(obj, methodName, &error));
}

template <>
zim::writer::Hints
_call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return hints_cy_call_fct(obj, methodName, &error);
}

template <>
zim::writer::IndexData::GeoPosition
_call_method_on_obj(PyObject *obj, const std::string &methodName, std::string &error)
{
  return geoposition_cy_call_fct(obj, methodName, &error);
}

// This cpp function call a python method on a python object.
// It checks that we are in a valid state and handle any potential error coming from python.
template <typename Output>
Output call_method_on_obj(PyObject *obj, const std::string &methodName)
{
  if (!obj)
  {
    throw std::runtime_error("Python object not set");
  }
  std::string error;
  Output out = _call_method_on_obj<Output>(obj, methodName, error);
  if (!error.empty())
  {
    throw std::runtime_error(error);
  }
  return out;
}

/*
################################
#  Content Provider Wrapper    #
################################
*/

zim::size_type ContentProviderWrapper::getSize() const
{
  return call_method_on_obj<uint64_t>(m_obj, "get_size");
}

zim::Blob ContentProviderWrapper::feed()
{
  return call_method_on_obj<zim::Blob>(m_obj, "feed");
}

/*
################################
#  Index Data Wrapper          #
################################
*/

bool IndexDataWrapper::hasIndexData() const
{
  return call_method_on_obj<bool>(m_obj, "has_indexdata");
}

std::string IndexDataWrapper::getTitle() const
{
  return call_method_on_obj<std::string>(m_obj, "get_title");
}

std::string IndexDataWrapper::getContent() const
{
  return call_method_on_obj<std::string>(m_obj, "get_content");
}

std::string IndexDataWrapper::getKeywords() const
{
  return call_method_on_obj<std::string>(m_obj, "get_keywords");
}

uint32_t IndexDataWrapper::getWordCount() const
{
  return call_method_on_obj<std::uint32_t>(m_obj, "get_wordcount");
}

zim::writer::IndexData::GeoPosition IndexDataWrapper::getGeoPosition() const
{
  return call_method_on_obj<zim::writer::IndexData::GeoPosition>(m_obj, "get_geoposition");
}

/*
#########################
#       WriterItem      #
#########################
*/

std::string
WriterItemWrapper::getPath() const
{
  return call_method_on_obj<std::string>(m_obj, "get_path");
}

std::string
WriterItemWrapper::getTitle() const
{
  return call_method_on_obj<std::string>(m_obj, "get_title");
}

std::string
WriterItemWrapper::getMimeType() const
{
  return call_method_on_obj<std::string>(m_obj, "get_mimetype");
}

std::unique_ptr<zim::writer::ContentProvider>
WriterItemWrapper::getContentProvider() const
{
  return call_method_on_obj<std::unique_ptr<zim::writer::ContentProvider>>(m_obj, "get_contentprovider");
}

std::shared_ptr<zim::writer::IndexData>
WriterItemWrapper::getIndexData() const
{
  // Item without method defined (should not happen on proper subclass)
  if (!obj_has_attribute(m_obj, "get_indexdata"))
  {
    return zim::writer::Item::getIndexData();
  }
  if (method_is_none(m_obj, "get_indexdata"))
  {
    return zim::writer::Item::getIndexData();
  }
  return call_method_on_obj<std::shared_ptr<zim::writer::IndexData>>(m_obj, "get_indexdata");
}

zim::writer::Hints WriterItemWrapper::getHints() const
{
  return call_method_on_obj<zim::writer::Hints>(m_obj, "get_hints");
}

zim::Compression comp_from_int(int compValue)
{
  switch (compValue)
  {
  case 0:
    return zim::Compression::None;
  case 1:
    return zim::Compression::Zstd;
  default:
    // Should we raise an error ?
    return zim::Compression::None;
  }
}
