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
#include "lib.h"

#include "wrapper_api.h"

#include <cstdlib>
#include <iostream>
#include <zim/blob.h>
#include <zim/writer/creator.h>


ObjWrapper::ObjWrapper(PyObject* obj)
  : m_obj(obj)
{
 if (import_libzim__wrapper()) {
    std::cerr << "Error executing import_libzim!\n";
    throw std::runtime_error("Error executing import_libzim");
  } else {
    Py_XINCREF(this->m_obj);
  }
}

ObjWrapper::~ObjWrapper()
{
  PyGILState_STATE gstate;
  gstate = PyGILState_Ensure();
  Py_XDECREF(this->m_obj);
  PyGILState_Release(gstate);
}

std::string ObjWrapper::callCythonReturnString(std::string methodName) const
{
  if (!this->m_obj)
    throw std::runtime_error("Python object not set");

  std::string error;

  std::string ret_val = string_cy_call_fct(this->m_obj, methodName, &error);
  if (!error.empty())
    throw std::runtime_error(error);
  return ret_val;
}

uint64_t ObjWrapper::callCythonReturnInt(std::string methodName) const
{
  if (!this->m_obj)
      throw std::runtime_error("Python object not set");

  std::string error;

  int64_t ret_val = int_cy_call_fct(this->m_obj, methodName, &error);
  if (!error.empty())
    throw std::runtime_error(error);

  return ret_val;
}


/*
################################
#  Content Provider Wrapper    #
################################
*/

zim::size_type ContentProviderWrapper::getSize() const
{
  return callCythonReturnInt("get_size");
}

zim::Blob ContentProviderWrapper::feed()
{
  return callCythonReturnBlob("feed");
}

zim::Blob ContentProviderWrapper::callCythonReturnBlob(std::string methodName) const
{
  if (!this->m_obj)
    throw std::runtime_error("Python object not set");

  std::string error;

  zim::Blob ret_val = blob_cy_call_fct(this->m_obj, methodName, &error);
  if (!error.empty())
    throw std::runtime_error(error);

  return ret_val;
}

/*
#########################
#       WriterItem      #
#########################
*/


std::unique_ptr<zim::writer::ContentProvider> WriterItemWrapper::callCythonReturnContentProvider(std::string methodName) const
{
  if (!this->m_obj)
    throw std::runtime_error("Python object not set");

  std::string error;

  auto ret_val = std::unique_ptr<zim::writer::ContentProvider>(contentprovider_cy_call_fct(this->m_obj, methodName, &error));
  if (!error.empty())
    throw std::runtime_error(error);

  return ret_val;
}

std::string
WriterItemWrapper::getPath() const
{
  return callCythonReturnString("get_path");
}

std::string
WriterItemWrapper::getTitle() const
{
  return callCythonReturnString("get_title");
}

std::string
WriterItemWrapper::getMimeType() const
{
  return callCythonReturnString("get_mimetype");
}

std::unique_ptr<zim::writer::ContentProvider>
WriterItemWrapper::getContentProvider() const
{
    return callCythonReturnContentProvider("get_contentProvider");
}
