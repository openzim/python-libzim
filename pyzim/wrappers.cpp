#include <string>
#include <iostream>

#include <zim/zim.h>
#include <zim/article.h>
#include <zim/blob.h>
#include <zim/writer/article.h>

#include <zim/file.h>
#include <zim/search.h>

#include <zim/writer/creator.h>

//  Article class to be passed to the zimwriter.
//  Contains an internal zim::Article class to be able to add artiles read with File

//  Overloads the constructor to create new zim::Articles to use with Creator addArticle

class ZimArticle : public zim::writer::Article
{
    zim::Article Ar;

public:
    explicit ZimArticle(const zim::Article a) : Ar(a)
    {
    }

    explicit ZimArticle(char ns,                                   // namespace
                        std::string aid,                           // article 
                        std::string url,                            
                        std::string title,
                        std::string mimeType,
                        std::string redirectUrl,
                        std::string fileName,
                        bool _shouldIndex,
                        char *bufferData,
                        size_t bufferLength) : ns(ns),
                                               aid(aid),
                                               url(url),
                                               title(title),
                                               mimeType(mimeType),
                                               redirectUrl(redirectUrl),
                                               fileName(fileName),
                                               _shouldIndex(_shouldIndex),
                                               bufferData(bufferData),
                                               bufferLength(bufferLength)
    {
        _data = zim::Blob(bufferData, bufferLength);
    }

    char ns;
    std::string aid;
    std::string url;
    std::string title;
    std::string mimeType;
    std::string redirectUrl;
    std::string fileName;
    bool _shouldIndex;
    char *bufferData;
    size_t bufferLength;
    zim::Blob _data;

    virtual zim::writer::Url getUrl() const
    {
        if (Ar.good())
            return zim::writer::Url(Ar.getNamespace(), Ar.getUrl());
        return zim::writer::Url(ns, url);
    }

    // virtual zim::writer::Url getUrl() const
    // {
    //     if(Ar.good())
    //         return zim::writer::Url((char) 0,Ar.getUrl());

    //     return zim::writer::Url((char) 0,url);
    // }

    virtual std::string getTitle() const
    {
        if (Ar.good())
            return Ar.getTitle();
        return title;
    }

    virtual bool isRedirect() const
    {
        if (Ar.good())
            return Ar.isRedirect();

        return !redirectUrl.empty();
    }

    virtual std::string getMimeType() const
    {
        if (Ar.good())
        {
            if (isRedirect())
            {
                return "";
            }
            return Ar.getMimeType();
        }
        return mimeType;
    }

    virtual zim::writer::Url getRedirectUrl() const
    {
        if (Ar.good())
        {
            auto redirectArticle = Ar.getRedirectArticle();
            return zim::writer::Url(redirectArticle.getNamespace(), redirectArticle.getUrl());
        }

        return zim::writer::Url(ns, redirectUrl);
    }

    virtual std::string getParameter() const
    {
        return Ar.getParameter();
    }

    zim::Blob getData() const
    {
        if (Ar.good())
            return Ar.getData();
        return _data;
    }

    zim::size_type getSize() const
    {
        if (Ar.good())
            return Ar.getArticleSize();
        return _data.size();
    }

    std::string getFilename() const
    {
        if (Ar.good())
            return "";
        return fileName;
    }

    bool shouldCompress() const
    {
        return getMimeType().find("text") == 0 || getMimeType() == "application/javascript" || getMimeType() == "application/json" || getMimeType() == "image/svg+xml";
    }

    bool shouldIndex() const
    {
        if (Ar.good())
            return getMimeType().find("text/html") == 0;
        return _shouldIndex;
    }
};

class ZimSearch : public zim::File
{
public:
    ZimSearch(zim::File *file) : _reader(file)
    {
    }

    ~ZimSearch()
    {
        delete _reader;
    }

    std::vector<std::string>
    suggest(std::string query)
    {
        std::vector<std::string> results;
        auto search = _reader->suggestions(query, 0, 10);
        for (auto it = search->begin(); it != search->end(); it++)
        {
            results.push_back(it->getLongUrl());
        }
        return results;
    }

    std::vector<std::string> search(std::string query)
    {
        std::vector<std::string> results;
        auto search = _reader->search(query, 0, 10);
        for (auto it = search->begin(); it != search->end(); it++)
        {
            results.push_back(it->getLongUrl());
        }
        // std::string url = it.get_snippet();
        // int numResults = search->get_matches_estimated();
        return results;
    }

    zim::File *_reader;
};

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

    std::string mainPage;
};

class ZimCreator
{
public:
    ZimCreator(OverriddenZimCreator *creator) : _creator(creator)
    {
    }

    ~ZimCreator()
    {
        delete _creator;
    }

    static ZimCreator *create(std::string fileName, std::string mainPage, std::string fullTextIndexLanguage, int minChunkSize)
    {
        bool shouldIndex = !fullTextIndexLanguage.empty();

        OverriddenZimCreator *c = new OverriddenZimCreator(mainPage); // TODO: consider when to delete this
        c->setIndexing(shouldIndex, fullTextIndexLanguage);
        c->setMinChunkSize(minChunkSize);
        c->startZimCreation(fileName);
        return (new ZimCreator(c));
    }

    void addArticle(std::shared_ptr<ZimArticle> article)
    {
        _creator->addArticle(article);
    }

    void finalise()
    {
        _creator->finishZimCreation();
        delete this;
    }

    OverriddenZimCreator *_creator;
};