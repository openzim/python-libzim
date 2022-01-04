// -*- c++ -*-
/*
 * This file is part of python-libzim
 * (see https://github.com/libzim/python-libzim)
 *
 * Copyright (c) 2021 Matthieu Gautier <mgautier@kymeria.fr>.
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

#ifndef LIBZIM_LIBWRAPPER_H
#define LIBZIM_LIBWRAPPER_H

#include <memory>
#include <zim/archive.h>
#include <zim/entry.h>
#include <zim/item.h>
#include <zim/writer/item.h>
#include <zim/writer/contentProvider.h>
#include <zim/search.h>
#include <zim/suggestion.h>

struct _object;
typedef _object PyObject;

// There are two kinds of wrapping :
//  - Wrapping C++ object to pass it in the Python world.
//  - Wrapping Python objects to pass it to the C++ world (mainly used by the creator).
//


// C++ wrapper side.
// The main issue here is that libzim classes cannot be "default constructed".
// libzim object are build by the libzim itself and are always "valid".
// But cython generate code using two instructions :
// The cython code `cdef Item item = archive.getItem(...)` is translated to :
// ```
// Item item;
// item = archive.getItem(...);
// ```
// Which is not possible because the Item has not default constructor.
// The solution is to manipulate all libzim object through pointers
// (pointer can be default constructed to nullptr).
// As the libzim functions/methods return directly the instance, we have to wrap all
// of them (in pure C++) to make them return a pointer.
// (Hopefully, copy constructor is available on libzim classes)
//
// To help us, we define a Wrapper class which wrap a libzim instance by storing
// a internel pointer to a heap allocated instance.
// This wrapper provide all constructors/helpers to build it and use the wrapped instance.
// (Especially, a default constructor)
//
// On top of that, we are writing specific wrapper to overwrite some method to return a
// Wrapper<Foo> instead of Foo.
// As Wrapper<Foo> do not inherit from Foo, we must define all the methods we want to wrap in python.
// Thoses methods just have to forward the call from the wrapper to the wrapped instance.
// As Wrapper<Foo> can be implicitly constructed from Foo, we can also simply forward the call and the
// conversion will be made for us.
// The macro FORWARD help us a lot here.

/**
 * A base wrapper for our structures
 */
template<typename Base>
class Wrapper {
  public:
    Wrapper() {}
    ~Wrapper() = default;
    Wrapper(const Base& base)
      : mp_base(new Base(base))
    {}
    Wrapper(Base&& base)
      : mp_base(new Base(std::move(base)))
    {}
    Wrapper(Wrapper&& other) = default;
    Wrapper& operator=(Wrapper&& other) = default;
  protected:
    std::unique_ptr<Base> mp_base;
};

#define FORWARD(OUT, NAME) template<class... ARGS> OUT NAME(ARGS&&... args) const { return mp_base->NAME(std::forward<ARGS>(args)...); }

namespace wrapper {
// Wrapping blob is not necessary as we can default construct a zim::Blob.
// But it is nice to have for consistancy.
class Blob : public Wrapper<zim::Blob>
{
  public:
    Blob() = default;
    Blob(const zim::Blob& o) : Wrapper(o) {}
    Blob(const char* data, zim::size_type size) : Wrapper(zim::Blob(data, size)) {};
    operator zim::Blob() { return *mp_base; }
    FORWARD(const char*, data)
    FORWARD(const char*, end)
    FORWARD(zim::size_type, size)
};

class Item : public Wrapper<zim::Item>
{
  public:
    Item() = default;
    Item(const zim::Item& o) : Wrapper(o) {}
    FORWARD(std::string, getTitle)
    FORWARD(std::string, getPath)
    FORWARD(std::string, getMimetype)
    FORWARD(wrapper::Blob, getData)
    FORWARD(zim::size_type, getSize)
    FORWARD(zim::entry_index_type, getIndex)
};

class Entry : public Wrapper<zim::Entry>
{
  public:
    Entry() = default;
    Entry(const zim::Entry& o) : Wrapper(o) {}
    FORWARD(std::string, getTitle)
    FORWARD(std::string, getPath)
    FORWARD(bool, isRedirect)
    FORWARD(wrapper::Item, getItem)
    FORWARD(wrapper::Item, getRedirect)
    FORWARD(wrapper::Entry, getRedirectEntry)
    FORWARD(zim::entry_index_type, getIndex)
};

class Archive : public Wrapper<zim::Archive>
{
  public:
    Archive() = default;
    Archive(const std::string& filename) : Wrapper(zim::Archive(filename)) {};
    Archive(const zim::Archive& o) : Wrapper(o) {};
    zim::Archive& operator*() const { return *mp_base; }

    FORWARD(wrapper::Entry, getEntryByPath)
    FORWARD(wrapper::Entry, getEntryByTitle)
    FORWARD(wrapper::Entry, getMainEntry)
    FORWARD(wrapper::Item, getIllustrationItem)
    FORWARD(std::set<unsigned int>, getIllustrationSizes)
    std::string getUuid() const
    { auto u = mp_base->getUuid();
      std::string uuids(u.data, u.size());
      return uuids;
    }
    FORWARD(zim::size_type, getFilesize)
    FORWARD(std::string, getMetadata)
    FORWARD(wrapper::Item, getMetadataItem)
    FORWARD(std::vector<std::string>, getMetadataKeys)
    FORWARD(zim::size_type, getEntryCount)
    FORWARD(zim::size_type, getAllEntryCount)
    FORWARD(zim::size_type, getArticleCount)
    FORWARD(std::string, getChecksum)
    FORWARD(std::string, getFilename)
    FORWARD(bool, hasMainEntry)
    FORWARD(bool, hasIllustration)
    FORWARD(bool, hasEntryByPath)
    FORWARD(bool, hasEntryByTitle)
    FORWARD(bool, isMultiPart)
    FORWARD(bool, hasNewNamespaceScheme)
    FORWARD(bool, hasFulltextIndex)
    FORWARD(bool, hasTitleIndex)
    FORWARD(bool, hasChecksum)
    FORWARD(bool, check)
};

class SearchResultSet : public Wrapper<zim::SearchResultSet>
{
  public:
    SearchResultSet() = default;
    SearchResultSet(const zim::SearchResultSet& o) : Wrapper(o) {};


    FORWARD(zim::SearchIterator, begin)
    FORWARD(zim::SearchIterator, end)
    FORWARD(int, size)
};

class Search : public Wrapper<zim::Search>
{
  public:
    Search() = default;
    Search(zim::Search&& s) : Wrapper(std::move(s)) {};

    FORWARD(int, getEstimatedMatches)
    FORWARD(wrapper::SearchResultSet, getResults)
};

class Searcher : public Wrapper<zim::Searcher>
{
  public:
    Searcher() = default;
    Searcher(const wrapper::Archive& a) : Wrapper(zim::Searcher(*a)) {};
    Searcher(const zim::Searcher& o) : Wrapper(o) {};

    FORWARD(void, setVerbose)
    FORWARD(wrapper::Search, search)
};

class SuggestionItem : public Wrapper<zim::SuggestionItem>
{
  public:
    SuggestionItem() = default;
    SuggestionItem(const zim::SuggestionItem& o) : Wrapper(o) {};

    FORWARD(std::string, getTitle)
    FORWARD(std::string, getPath)
    FORWARD(std::string, getSnippet)
    FORWARD(bool, hasSnippet)
};

class SuggestionIterator : public Wrapper<zim::SuggestionIterator>
{
  public:
    SuggestionIterator() = default;
    SuggestionIterator(const zim::SuggestionIterator& o) : Wrapper(o) {};
    zim::SuggestionIterator& operator*() const { return *mp_base; }

    FORWARD(bool, operator==)
    bool operator!=(const wrapper::SuggestionIterator& it) const {
      return *mp_base != *it;
    }
    FORWARD(wrapper::SuggestionIterator, operator++)
    SuggestionItem getSuggestionItem() const {
      return mp_base->operator*();
    }
//    FORWARD(wrapper::SuggestionItem, operator*)
    FORWARD(wrapper::Entry, getEntry)
};

class SuggestionResultSet : public Wrapper<zim::SuggestionResultSet>
{
  public:
    SuggestionResultSet() = default;
    SuggestionResultSet(const zim::SuggestionResultSet& o) : Wrapper(o) {};


    FORWARD(wrapper::SuggestionIterator, begin)
    FORWARD(wrapper::SuggestionIterator, end)
    FORWARD(int, size)
};


class SuggestionSearch : public Wrapper<zim::SuggestionSearch>
{
  public:
    SuggestionSearch() = default;
    SuggestionSearch(zim::SuggestionSearch&& s) : Wrapper(std::move(s)) {};

    FORWARD(int, getEstimatedMatches)
    FORWARD(wrapper::SuggestionResultSet, getResults)
};

class SuggestionSearcher : public Wrapper<zim::SuggestionSearcher>
{
  public:
    SuggestionSearcher() = default;
    SuggestionSearcher(const wrapper::Archive& a) : Wrapper(zim::SuggestionSearcher(*a)) {};
    SuggestionSearcher(const zim::SuggestionSearcher& o) : Wrapper(o) {};

    FORWARD(void, setVerbose)
    FORWARD(wrapper::SuggestionSearch, suggest)
};
} // namespace wrapper
#undef FORWARD


// Python wrapper
//
// The main issue is to forward the c++ method call (made by `zim::Creator`) to the
// python method.
//
// To do so, we define a helper wrapper (ObjWrapper) which wrap a PyObject and allow us to call
// different kind of methods (signatures).
// Then we write specific wrapper to forward the call using helper methods of ObjWrapper.

class ObjWrapper
{
  public:
    ObjWrapper(PyObject* obj);
    ObjWrapper(const ObjWrapper& other) = delete;
    ObjWrapper(ObjWrapper&& other);
    ~ObjWrapper();
    ObjWrapper& operator=(ObjWrapper&& other);


  protected:
    PyObject* m_obj;
};

class WriterItemWrapper : public zim::writer::Item, private ObjWrapper
{
  public:
    WriterItemWrapper(PyObject *obj) : ObjWrapper(obj) {};
    ~WriterItemWrapper() = default;
    std::string getPath() const override;
    std::string getTitle() const override;
    std::string getMimeType() const override;
    std::unique_ptr<zim::writer::ContentProvider> getContentProvider() const override;
    zim::writer::Hints getHints() const override;
};

class ContentProviderWrapper : public zim::writer::ContentProvider, private ObjWrapper
{
  public:
    ContentProviderWrapper(PyObject *obj) : ObjWrapper(obj) {};
    ~ContentProviderWrapper() = default;
    zim::size_type getSize() const override;
    zim::Blob feed() override;
};


// Small helpers

// The current stable cython version (0.29.24) doesn't support scoped enum (next version >30 will be).
// The cython generated __Pyx_PyInt_As_enum__zim_3a__3a_Compression(PyOobject*)
// try to do some strange bit shifting of `zim::Compression` which doesn't compile.
// Let's provide our own function for this
zim::Compression comp_from_int(int compValue);

#endif // LIBZIM_LIBWRAPPER_H
