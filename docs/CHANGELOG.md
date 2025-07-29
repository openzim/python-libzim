# Changelog

Any notable changes to the project are listed here.



## [3.7.0] 2025-04-18

### Added

- Set up documentation using mkdocs, published on readthedocs.com
- Archive.get_random_entry()
- libzim 9.3.0 Cache Control API:
    - Archive.cluster_cache_max_size
    - Archive.cluster_cache_current_size
    - Archive.dirent_cache_max_size
    - Archive.dirent_cache_current_size
    - Archive.dirent_lookup_cache_max_size

### Changed

- Using C++ libzim 9.3.0-1



## [3.6.0] 2024-10-15

### Added

- Support for Python 3.13

### Changed

- delocate dependency only required on Windows platform



## [3.5.0] 2024-09-09

### Added

- Windows (x64) support
- Type stubs

### Changed

- Using C++ libzim 9.2.3-2



## [3.4.0] 2023-12-16

### Added

- New Creator.add_alias method for multiple entries pointing to same content

### Changed

- Using C++ libzim 9.1.0



## [3.3.0] 2023-11-16

### Added

- Support for Python 3.12
- Support (and wheels) for musl/Alpine

### Changed

- Using C++ libzim 9.0.0


## [3.2.0] 2023-09-15

### Added

- Added clean command to setup.py to remove downloaded libzim

### Changed

- Build with (and target) libzim 8.2.1
- Fixed setup checking download platform even when using own libzim (not downloading)

### Removed

- Support for Python 3.7 (EOL)


## [3.1.0] 2023-04-01

### Changed

- Revamped setup to create proper wheels and sdist out-of-the-box (python3 -m build)
    - Build can now sign + notarize for macOS
    - Build can now create macOS universal wheels
    - Added cibuildwheel config
- Build with (and target) libzim 8.2.0



## [3.0.0] 2023-03-16

### Added

- version module with
    - version.get_versions() returning an OrderedDict of library:version inclusing libzim
    - version.print_versions() print it on stdout (or another fd)
    - version.get_libzim_version() returns the libzim version only
 
### Changed

- Creator.add_metadata no longer transforms (~pascalize) name

### Removed

- writer.pascalize function



## [2.1.0] 2022-12-06

### Added

- Archive.media_count
- Python 3.11 Support

### Changed

- Using libzim 8.1.0
- Exceptions in getIndexData dont crash interpreter



## [2.0.0] 2022-09-06

### Changed

- Using libzim 8.0.0

### Removed 

- Removed lzma compression option



## [1.1.1] 2022-06-17

### Changed

- Building with Cython 0.29.30
- Specifying max python version to 3.10.x in metadata (prevents Python 3.11 users from accidentally trying to install libzim)



## [1.1.0] 2022-05-23

### Added

- Archive.get_metadata_item() 
- Python 3.10 Support

### Changed

- using libzim 7.2.2
    - RuntimeError exception is now raised on invalid/duplicate entries
- Allow setting mimetype for metadata
- Updated Cython to 0.29.28
- Fixed Archive.filesize

### Removed

- skip cython on setup.py clean 
- OFFLINE environ skips network-using tests



## [1.0.0] 2021-10-09

### Added

- Python 3.9 support

### Changed

- Early-failure on invalid destination ZIM path
- Using libzim 7.x
- Using new libzim 7-based API for both reader and writer
    - No more namespaces
    - Defaulting to zstd compression
- Rewrote all tests for new API ; using libzim's own test ZIM files to test reader
- Code-coverage now includes Cython code as well
- macOS releases are signed and notarized



## [0.1.0] 2021-06-10

### Changed

- Using libzim 6.3.2



## [0.0.3] 2020-07-01

### Added 

- added get_redirect_article() to reader
- added _closed property to writer
- added macOS support

### Changed

- fixed main_page retrieval for reader
- provide reader access to redirect target via get_redirect_article()
- fixed ReadArticle.__repr__ for reader
- fixed reader raising IndexError and KeyError on incorrect url/ID
- reader's File.get_metadata() now returns bytes
- cleaner reader API for reader
    - added/fixed all docstrings, including annotations
    - File can be used as a contextmanager
    - File.get_namespaces_count() renamed to get_namespace_count()
- writer's Creator now closed upon deletion\
- writers' min_chunk_size and index_language now optional at Creator init
- writer's Creator now uses pathlib.Path for filename
- cleaner Creator API for write
    - added/fixed all docstrings, including annotations
    - added _closed property
    - removed _get_counter_string()
    - removed write_metadata()
    - removed _update_article_counter)_
    - removed pascalize()
    - update_metadata() accepts datetime.datetime for Date
- writer exceptions in Article methods now forwarded to python (as RuntimeError with details in message)
- fixed creation of redirect from Article (get_redirect_url()) in writer
- building with Cython 0.29.20+
- using libzim 6.1.7
- removed ZIM filename printed on stdout at Creator init in writer



## [0.0.1/0.0.2] 2020-06-04
The first release of python-libzim.
