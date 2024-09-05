# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Windows (x64) support (#91)
- Type stubs (#198)

### Changed

- Using C++ libzim 9.2.3-2

### Removed

- Support for Python 3.8 (EOL)

## [3.4.0] - 2023-12-16

### Added

- New `Creator.add_alias` method for multiple entries pointing to same content

### Changed

- Using C++ libzim 9.1.0

## [3.3.0] - 2023-11-15

### Added

- Support for Python 3.12
- Support (and wheels) for musl/Alpine

### Changed

- Using C++ libzim 9.0.0

## [3.2.0] - 2023-09-15

### Added

- Added `clean` command to setup.py to remove downloaded libzim

### Changed

- Build with (and target) libzim 8.2.1
- Fixed setup checking download platform even when using own libzim (not downloading)

## Removed

- Support for Python 3.7 (EOL)

## [3.1.0] - 2023-05-01

### Changed

- Revamped setup to create proper wheels and sdist out-of-the-box (`python3 -m build`)
  - Build can now sign + notarize for macOS
  - Build can now create macOS universal wheels
  - Added cibuildwheel config
- Build with (and target) libzim 8.2.0

## [3.0.0] - 2023-03-16

### Added

* `version` module with
  * `version.get_versions()` returning an OrderedDict of library:version inclusing libzim
  * `version.print_versions()` print it on stdout (or another fd)
  * `version.get_libzim_version()` returns the libzim version only

### Changed

* `Creator.add_metadata` no longer transforms (~pascalize) name (#161)

### Removed

* `writer.pascalize` function

## [2.1.0] - 2022-12-06

### Added

* `Archive.media_count`
* Python 3.11 Support

### Changed

* Using libzim 8.1.0
* Exceptions in getIndexData dont crash interpreter (#153)

## [2.0.0] - 2022-09-06

### Removed

* Removed `lzma` compression option (#150)

### Changed

* Using libzim 8.0.0

## [1.1.1] – 2022-06-17

### Changed

* Building with Cython 0.29.30
* Specifying max python version to 3.10.x in metadata

## [1.1.0] - 2022-05-23

### Added

* `Archive.get_metadata_item()` (#127)
* Python 3.10 Support

### Changed

* using libzim 7.2.2
  * RuntimeError exception is now raised on invalid/duplicate entries
* Allow setting mimetype for metadata
* Updated Cython to 0.29.28
* Fixed `Archive.filesize` (#137)

### Removed

* skip cython on setup.py clean (#131)
* `OFFLINE` environ skips network-using tests (#132)

## [1.0.0] - 2021-10-09

* using libzim 7.0.0
* Python 3.9 support
* [breaking] Using new libzim 7-based API for both reader and writer
  * No more namespaces
  * Defaulting to zstd compression
  * https://github.com/openzim/libzim/blob/master/ChangeLog
* Rewrote all tests for new API ; using libzim's own test ZIM files to test reader
* Code-coverage now includes Cython code as well
* macOS releases are signed and notarized
* Early-failure on invalid destination ZIM path

## [0.0.4]

* added compression argument to Creator to set compression algorithm (libzim.writer.Compression)
* Creator positional arguments order changed: min_chunk_size moved after compression
* Reader `get_suggestions_results_count` renamed `get_estimated_suggestions_results_count` (#71)
* Reader `get_search_results_count` renamed `get_estimated_search_results_count` (#71)
* Article subclasses must implement `get_size()`
* Fixed using `get_filename()` (#71)
* using libzim 6.1.8

## [0.0.3.post0]

* fixed access to bundled libzim on macOS (missing rpath)

## [0.0.3]

* [reader] fixed `main_page` retrieval
* [reader] provide access to redirect target via `get_redirect_article()` (#51)
* [reader] fixed `ReadArticle.__repr__` (#37)
* [reader] raising `IndexError` and `KeyError` on incorrect url/ID (#38)
* [reader] `File.get_metadata()` now returns `bytes` (#30)
* [reader] cleaner reader API
  * added/fixed all docstrings, including annotations
  * `File` can be used as a contextmanager
  * `File.get_namespaces_count()` renamed to `get_namespace_count()`
* [writer] removed ZIM filename printed on stdout at Creator init
* [writer] Creator now closed upon deletion (#31)
* [writer] `min_chunk_size` and `index_language` now optional at Creator init (#29)
* [writer] Creator now uses `pathlib.Path` for `filename` (#45)
* [writer] cleaner Creator API
  * added/fixed all docstrings, including annotations
  * added `_closed` property
  * removed `_get_counter_string()`
  * removed `write_metadata()`
  * removed `_update_article_counter)_`
  * removed `pascalize()`
  * `update_metadata()` accepts `datetime.datetime` for `Date`
* [writer] exceptions in `Article` methods now forwarded to python (as `RuntimeError` with details in message)
* [writer] fixed creation of redirect from `Article` (`get_redirect_url()`)
* added macOS support (#35)
* building with Cython 0.29.20+
* using libzim 6.1.7

## [0.0.2]

* initial release
* using libzim 6.1.6
