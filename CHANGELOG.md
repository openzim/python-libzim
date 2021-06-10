## 0.1

* Using libzim 6.3.2 which compresses zstd at level 19 which is required 
  to keep decompression RAM allocation under control on 32b systems

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
