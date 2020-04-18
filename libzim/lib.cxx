#include <Python.h>
#include "lib.h"

#include "libzim_api.h"

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
    if (import_libzim())
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
    Py_XDECREF(this->m_obj);
}

std::string ZimArticleWrapper::callCythonReturnString(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    int error;

    std::string ret_val = string_cy_call_fct(this->m_obj, methodName, &error);
    if (error)
        throw std::runtime_error("The pure virtual function " + methodName + " must be override");

    return ret_val;
}

zim::Blob ZimArticleWrapper::callCythonReturnBlob(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    int error;

    zim::Blob ret_val = blob_cy_call_fct(this->m_obj, methodName, &error);
    if (error)
        throw std::runtime_error("The pure virtual function " + methodName + " must be override");

    return ret_val;
}

bool ZimArticleWrapper::callCythonReturnBool(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    int error;

    bool ret_val = bool_cy_call_fct(this->m_obj, methodName, &error);
    if (error)
        throw std::runtime_error("The pure virtual function " + methodName + " must be override");

    return ret_val;
}

uint64_t ZimArticleWrapper::callCythonReturnInt(std::string methodName) const
{
    if (!this->m_obj)
        throw std::runtime_error("Python object not set");

    int error;

    int ret_val = int_cy_call_fct(this->m_obj, methodName, &error);
    if (error)
        throw std::runtime_error("The pure virtual function " + methodName + " must be override");

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

    std::string redirectUrl = callCythonReturnString("get_url");
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
    return callCythonReturnBlob("get_data");
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

    virtual zim::writer::Url getMainUrl()
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