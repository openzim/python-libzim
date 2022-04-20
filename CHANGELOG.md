## 1.1.0

* Allow setting mimetype for metadata
* added getMetadataItem support (#127)
* skip cython on setup.py clean (#131)
* OFFLINE environ skips network-using tests (#132)
* Added Python3.10 Support
* Updated Cython to 0.29.26
* Fixed `Archive.filesize` (#137)

## 1.0.0

* using libzim 7.x
* Python 3.9 support
* [breaking] Using new libzim 7-based API for both reader and writer
  * No more namespaces
  * Defaulting to zstd compression
  * https://github.com/openzim/libzim/blob/master/ChangeLog
* Rewrote all tests for new API ; using libzim's own test ZIM files to test reader
* Code-coverage now includes Cython code as well
* macOS releases are signed and notarized
* Early-failure on invalid destination ZIM path

## 0.0.4

* added compression argument to Creator to set compression algorithm (libzim.writer.Compression)
* Creator positional arguments order changed: min_chunk_size moved after compression
* Reader `get_suggestions_results_count` renamed `get_estimated_suggestions_results_count` (#71)
* Reader `get_search_results_count` renamed `get_estimated_search_results_count` (#71)
* Article subclasses must implement `get_size()`
* Fixed using `get_filename()` (#71)
* using libzim 6.1.8

## 0.0.3.post0

* fixed access to bundled libzim on macOS (missing rpath)

## 0.0.3

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

## 0.0.2

* initial release
* using libzim 6.1.6
