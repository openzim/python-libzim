// -*- c++ -*-
/*
 * This file is part of python-libzim
 * (see https://github.com/libzim/python-libzim)
 *
 * Copyright (c) 2020 Juan Diego Caballero <jdc@monadical.com>.
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
#ifndef libzim_LIB_H
#define libzim_LIB_H 1

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
    void finalize();
    void setMainUrl(std::string newUrl);
    zim::writer::Url getMainUrl();
};

#endif // !libzim_LIB_H
