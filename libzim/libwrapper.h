// -*- c++ -*-
/*
 * This file is part of python-libzim
 * (see https://github.com/libzim/python-libzim)
 *
 * Copyright (c) 2021 Matthieu Gautier <mgautier@kymeria.fr>.
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

#ifndef LIBZIM_LIBWRAPPER_H
#define LIBZIM_LIBWRAPPER_H

#include <memory>
#include <zim/archive.h>
#include <zim/entry.h>
#include <zim/item.h>
#include <zim/writer/item.h>
#include <zim/writer/contentProvider.h>

struct _object;
typedef _object PyObject;

// There is two kind of wrapping :
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
// The solution is to manipulate all libzim object throw pointer
// (pointer can be defaul constructed to nullptr).
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
// As Wrapper<Foo> can be implicitly construct from Foo, we can also simply forward the call and the
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
    Wrapper(Wrapper&& other) = default;
    Wrapper& operator=(Wrapper&& other) = default;
  protected:
    std::unique_ptr<Base> mp_base;
};

#define FORWARD(OUT, NAME) template<class... ARGS> OUT NAME(ARGS&&... args) const { return mp_base->NAME(std::forward<ARGS>(args)...); }



class WItem : public Wrapper<zim::Item>
{
  public:
    WItem() = default;
    WItem(const zim::Item& o) : Wrapper(o) {}
    FORWARD(std::string, getTitle)
    FORWARD(std::string, getPath)
    FORWARD(std::string, getMimetype)
    FORWARD(zim::Blob, getData)
    FORWARD(zim::size_type, getSize)
    FORWARD(zim::entry_index_type, getIndex)
};

class WEntry : public Wrapper<zim::Entry>
{
  public:
    WEntry() = default;
    WEntry(const zim::Entry& o) : Wrapper(o) {}
    FORWARD(std::string, getTitle)
    FORWARD(std::string, getPath)
    FORWARD(bool, isRedirect)
    FORWARD(WItem, getItem)
    FORWARD(WItem, getRedirect)
    FORWARD(WEntry, getRedirectEntry)
    FORWARD(zim::entry_index_type, getIndex)
};

class WArchive : public Wrapper<zim::Archive>
{
  public:
    WArchive() = default;
    WArchive(const std::string& filename) : Wrapper(zim::Archive(filename)) {};
    WArchive(const zim::Archive& o) : Wrapper(o) {};

    FORWARD(WEntry, getEntryByPath)
    FORWARD(WEntry, getEntryByTitle)
    FORWARD(WEntry, getMainEntry)
    FORWARD(WItem, getIllustrationItem)
    std::string getUuid() const
    { auto u = mp_base->getUuid();
      std::string uuids(u.data, u.size());
      return uuids;
    }
    FORWARD(zim::size_type, getFilesize)
    FORWARD(std::string, getMetadata)
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
    FORWARD(bool, is_multiPart)
    FORWARD(bool, hasNewNamespaceScheme)
    FORWARD(bool, hasFulltextIndex)
    FORWARD(bool, hasTitleIndex)
    FORWARD(bool, hasChecksum)
    FORWARD(bool, check)
};

#undef FORWARD



class ObjWrapper
{
  public:
    ObjWrapper(PyObject* obj);
    virtual ~ObjWrapper();

  protected:
    PyObject* m_obj;

    std::string callCythonReturnString(std::string) const;
    uint64_t callCythonReturnInt(std::string) const;
};

class WriterItemWrapper : public zim::writer::Item, private ObjWrapper
{
  public:
    WriterItemWrapper(PyObject *obj) : ObjWrapper(obj) {};
    virtual std::string getPath() const;
    virtual std::string getTitle() const;
    virtual std::string getMimeType() const;
    virtual std::unique_ptr<zim::writer::ContentProvider> getContentProvider() const;
    virtual zim::writer::Hints getHints() const;

  private:
    std::unique_ptr<zim::writer::ContentProvider> callCythonReturnContentProvider(std::string) const;
    zim::writer::Hints callCythonReturnHints(std::string) const;
};

class ContentProviderWrapper : public zim::writer::ContentProvider, private ObjWrapper
{
  public:
    ContentProviderWrapper(PyObject *obj) : ObjWrapper(obj) {};
    virtual zim::size_type getSize() const;
    virtual zim::Blob feed();
  private:
    zim::Blob callCythonReturnBlob(std::string) const;
};

#endif // LIBZIM_LIBWRAPPER_H
