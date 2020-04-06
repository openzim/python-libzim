// -*- c++ -*-
#ifndef PYZIM_LIB_H
#define PYZIM_LIB_H 1

struct _object;
typedef _object PyObject;

#include <zim/zim.h>
#include <zim/writer/article.h>
#include <zim/writer/url.h>
#include <zim/blob.h>

#include <string>

class ZimArticleWrapper : public zim::writer::Article
{
public:
    PyObject *m_obj;

    ZimArticleWrapper(PyObject *obj);
    virtual ~ZimArticleWrapper();

    virtual zim::writer::Url getUrl() const;
    virtual std::string getTitle() const;
    virtual bool isRedirect() const;
    virtual std::string getMimeType() const;
    virtual std::string getFilename() const;
    virtual bool shouldCompress() const;
    virtual bool shouldIndex() const;
    virtual zim::writer::Url getRedirectUrl() const;
    virtual zim::Blob getData() const;
    virtual zim::size_type getSize() const;

    virtual bool isLinktarget() const;
    virtual bool isDeleted() const;
    virtual std::string getNextCategory();


private:
    std::string callCythonReturnString(std::string) const;
    zim::Blob callCythonReturnBlob(std::string) const;
    bool callCythonReturnBool(std::string) const;
    uint64_t callCythonReturnInt(std::string) const;
};

class OverriddenZimCreator;

class ZimCreatorWrapper
{
public:
    OverriddenZimCreator *_creator;
    ZimCreatorWrapper(OverriddenZimCreator *creator);
    ~ZimCreatorWrapper();
    static ZimCreatorWrapper *create(std::string fileName, std::string mainPage, std::string fullTextIndexLanguage, int minChunkSize);
    void addArticle(std::shared_ptr<ZimArticleWrapper> article);
    void finalise();
};

#endif // !PYZIM_LIB_H