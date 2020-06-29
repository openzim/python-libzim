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
#include <zim/writer/url.h>
#include <zim/blob.h>
#include <zim/writer/creator.h>

/*
#########################
#       ZimArticle      #
#########################
*/

ZimArticleWrapper::ZimArticleWrapper(PyObject *obj) : m_obj(obj)
{
    if (import_libzim__wrapper())
    {
        std::cerr << "Error executing import_libzim!\n";
        throw std::runtime_error("Error executing import_libzim");
    }
    else
    {
        Py_XINCREF(this->m_obj);
    }
}

ZimArticleWrapper::~ZimArticleWrapper()
{
  PyGILState_STATE gstate;
  gstate = PyGILState_Ensure();
    Py_XDECREF(this->m_obj);
  PyGILState_Release(gstate);
}

std::string ZimArticleWrapper::callCythonReturnString(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    std::string error;

    std::string ret_val = string_cy_call_fct(this->m_obj, methodName, &error);
    if (!error.empty())
        throw std::runtime_error(error);

    return ret_val;
}

zim::Blob ZimArticleWrapper::callCythonReturnBlob(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    std::string error;

    zim::Blob ret_val = blob_cy_call_fct(this->m_obj, methodName, &error);
    if (!error.empty())
        throw std::runtime_error(error);

    return ret_val;
}

bool ZimArticleWrapper::callCythonReturnBool(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    std::string error;

    bool ret_val = bool_cy_call_fct(this->m_obj, methodName, &error);
    if (!error.empty())
        throw std::runtime_error(error);

    return ret_val;
}

uint64_t ZimArticleWrapper::callCythonReturnInt(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    std::string error;

    int64_t ret_val = int_cy_call_fct(this->m_obj, methodName, &error);
    if (!error.empty())
        throw std::runtime_error(error);

    return ret_val;
}
zim::writer::Url
ZimArticleWrapper::getUrl() const
{

    std::string url = callCythonReturnString("get_url");

    return zim::writer::Url(url.substr(0, 1)[0], url.substr(2, url.length()));
}

std::string
ZimArticleWrapper::getTitle() const
{
    return callCythonReturnString("get_title");
}

bool ZimArticleWrapper::isRedirect() const
{
    return callCythonReturnBool("is_redirect");
}

std::string
ZimArticleWrapper::getMimeType() const
{
    return callCythonReturnString("get_mime_type");
}

std::string
ZimArticleWrapper::getFilename() const
{
    return callCythonReturnString("get_filename");
}

bool ZimArticleWrapper::shouldCompress() const
{
    return callCythonReturnBool("should_compress");
}

bool ZimArticleWrapper::shouldIndex() const
{
    return callCythonReturnBool("should_index");
}

zim::writer::Url
ZimArticleWrapper::getRedirectUrl() const
{

    std::string redirectUrl = callCythonReturnString("get_redirect_url");
    return zim::writer::Url(redirectUrl.substr(0, 1)[0], redirectUrl.substr(2, redirectUrl.length()));
}

// zim::Blob
// ZimArticleWrapper::getData() const
// {
//     std::string content = callCythonReturnString("get_data");
//     return zim::Blob(&content[0], content.size());
// }

zim::Blob
ZimArticleWrapper::getData() const
{
    return callCythonReturnBlob("_get_data");
}

zim::size_type
ZimArticleWrapper::getSize() const
{
    return this->getData().size();
}

bool ZimArticleWrapper::isLinktarget() const
{
    return false;
}

bool ZimArticleWrapper::isDeleted() const
{
    return false;
}

std::string ZimArticleWrapper::getNextCategory()
{
    return std::string();
}

/*
#########################
#       ZimCreator      #
#########################
*/

class OverriddenZimCreator : public zim::writer::Creator
{
public:
    OverriddenZimCreator(std::string mainPage)
        : zim::writer::Creator(true),
          mainPage(mainPage) {}

    virtual zim::writer::Url getMainUrl() const
    {
        return zim::writer::Url('A', mainPage);
    }

    void setMainUrl(std::string newUrl)
    {
        mainPage = newUrl;
    }

    std::string mainPage;
};

ZimCreatorWrapper::ZimCreatorWrapper(OverriddenZimCreator *creator) : _creator(creator)
{
}

ZimCreatorWrapper::~ZimCreatorWrapper()
{
    delete _creator;
}

ZimCreatorWrapper *
ZimCreatorWrapper::
    create(std::string fileName, std::string mainPage, std::string fullTextIndexLanguage, int minChunkSize)

{
    bool shouldIndex = !fullTextIndexLanguage.empty();

    OverriddenZimCreator *c = new OverriddenZimCreator(mainPage);
    c->setIndexing(shouldIndex, fullTextIndexLanguage);
    c->setMinChunkSize(minChunkSize);
    c->startZimCreation(fileName);
    return (new ZimCreatorWrapper(c));
}

void ZimCreatorWrapper::addArticle(std::shared_ptr<ZimArticleWrapper> article)
{
    _creator->addArticle(article);
}

void ZimCreatorWrapper::finalize()
{
    _creator->finishZimCreation();
}

void ZimCreatorWrapper::setMainUrl(std::string newUrl)
{
    _creator->setMainUrl(newUrl);
}

zim::writer::Url ZimCreatorWrapper::getMainUrl()
{
    return _creator->getMainUrl();
}
