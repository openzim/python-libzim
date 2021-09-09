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
struct _object;
typedef _object PyObject;

#include <zim/zim.h>
#include <zim/archive.h>
#include <zim/entry.h>
#include <zim/item.h>
#include <zim/search.h>
#include <zim/blob.h>
#include <zim/writer/item.h>
#include <zim/writer/contentProvider.h>

#include <string>

template<typename T, typename U>
inline T* to_ptr(const U& obj)
{
  return new T(obj);
}

class ZimItem : public zim::Item
{
  public:
    ZimItem(const zim::Item& item) : zim::Item(item) {}
};

class ZimEntry : public zim::Entry
{
  public:
    ZimEntry(const zim::Entry& entry) : zim::Entry(entry) {}
    ZimItem* getItem(bool follow) const
    { return to_ptr<ZimItem>(zim::Entry::getItem(follow)); }
    ZimEntry* getRedirectEntry() const
    { return to_ptr<ZimEntry>(zim::Entry::getRedirectEntry()); }
};

// class ZimSearch : public zim::Search
// {
//   public:
//     ZimSearch() : zim::Search(std::vector<zim::Archive>{}) {};
//     ZimSearch(zim::Archive& archive) : zim::Search(archive) {};
//     ZimSearch(const Search& search) : zim::Search(search) {};
// };

class ZimArchive : public zim::Archive
{
  public:
    ZimArchive(const std::string& filename) : zim::Archive(filename) {};
    ZimArchive(const zim::Archive& archive) : zim::Archive(archive) {};

    ZimEntry* getEntryByPath(zim::entry_index_type idx) const
    { return to_ptr<ZimEntry>(zim::Archive::getEntryByPath(idx)); }
    ZimEntry* getEntryByPath(const std::string& path) const
    { return to_ptr<ZimEntry>(zim::Archive::getEntryByPath(path)); }
    ZimEntry* getEntryByTitle(zim::entry_index_type idx) const
    { return to_ptr<ZimEntry>(zim::Archive::getEntryByTitle(idx)); }
    ZimEntry* getEntryByTitle(const std::string& title) const
    { return to_ptr<ZimEntry>(zim::Archive::getEntryByTitle(title)); }
    ZimEntry* getMainEntry() const
    { return to_ptr<ZimEntry>(zim::Archive::getMainEntry()); }
    // ZimEntry* getFaviconEntry() const
    // { return to_ptr<ZimEntry>(zim::Archive::getFaviconEntry()); }
    ZimItem* getIllustrationItem() const
    { return to_ptr<ZimItem>(zim::Archive::getIllustrationItem()); }
    ZimItem* getIllustrationItem(unsigned int size) const
    { return to_ptr<ZimItem>(zim::Archive::getIllustrationItem(size)); }
    std::string getUuid() const
    { zim::Uuid uuid = zim::Archive::getUuid();
      std::string uuids(uuid.data, uuid.size()); return uuids; }
};



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
