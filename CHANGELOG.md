# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.0.0] - 2026-10-29

### Added

- Add support for Python 3.15 (#281)
- Build wheels against the stable ABI (abi3) so a single wheel per platform covers all supported CPython versions (#264)
- Add `libzim.illustration` module with the `IllustrationInfo` value object, and width/height/scale-aware illustration APIs: `Creator.add_illustration()`/`add_illustration_info()`, `Archive.get_illustration_item()`/`get_illustration_item_info()`, `Archive.get_illustrations_info()` (#232)
- Support multi-archive searching via `Searcher.add_archive()` (#230)
- Add `SearchResult` object with `archive`, `path`, `title`, and `snippet` (#226)

### Changed

- **Breaking**: `SearchResultSet` now yields `SearchResult` objects instead of entry path strings (#226)
- **Breaking**: `Creator.config_nbworkers()` param `nbWorkers` renamed `nb_workers` (#200)
- **Breaking**: `Creator.set_mainpath()` param `mainPath` renamed `main_path` (#200)
- **Breaking**: `Creator.add_redirection()` param `targetPath` renamed `target_path` (#200)
- **Breaking**: `Creator.add_alias()` param `targetPath` renamed `target_path` (#200)
- **Breaking**: `Search.getEstimatedMatches()` renamed `Search.get_estimated_matches()` (#200)
- **Breaking**: `Search.getResults()` renamed `Search.get_results()` (#200)
- **Breaking**: `SuggestionSearch.getEstimatedMatches()` renamed `SuggestionSearch.get_estimated_matches()` (#200)
- **Breaking**: `SuggestionSearch.getResults()` renamed `SuggestionSearch.get_results()` (#200)
- Declare the extension free-threading compatible so that importing it on a free-threaded CPython no longer forces the GIL back on (#240)
- Modernize type hints in `libzim.pyx` to use PEP 604/585 syntax (e.g. `str | bytes`, `dict[...]`) instead of `typing.Union`/`typing.Dict`/etc. (#281)

### Removed

- **Breaking**: Drop support for Python 3.10 (#281)
- **Breaking**: `Creator.add_metadata` no longer auto-converts a `Date` metadata value passed as `datetime.date`/`datetime.datetime`; pass pre-formatted `str`/`bytes` instead (#188)
- **Breaking**: `Archive._get_entry_by_id()` removed in favor of `Archive.get_entry_by_id()` (#225)

### Fixed

- Fix documentation build broken by mkdocstrings-python `import`/`load_external_modules` config changes and a stale CI badge URL (#279)
- `get_illustration_sizes()` deprecation warning now points to the existing `get_illustrations_info()` method (#272)
- `Creator.add_metadata` type stub no longer advertises `datetime` values (#285)
- `libzim.suggestion` now exports `SuggestionSearch` and `SuggestionResultSet` at runtime, as declared in type stubs (#286)
- Fix type stubs drifting from the compiled module: `set_cluster_cache_max_size` parameter name, `IllustrationInfo` `extra_attributes` default, enum members, `Creator.config_*()` return type (#286)
- Submodules are no longer also registered in `sys.modules` under their last member name (e.g. `sys.modules["Searcher"]`) (#286)

## [3.13.1] - 2026-10-05

### Changed

- Upgrade to libzim 9.8.2-1 and upgrade other Python dependencies (#269)

## [3.13.0] - 2026-09-07

### Changed

- Upgrade to libzim 9.8.2 and upgrade other Python dependencies, especially Cython 3.3.0 (#265)

## [3.12.0] - 2026-07-20

### Changed

- Upgrade to libzim 9.8.1 and upgrade other Python dependencies, especially Cython 3.2.8 (#261)
- Drop support for free-threaded CPython 3.13t (#261)

## [3.11.0] - 2026-07-09

### Changed

- Upgrade to libzim 9.8.0 (#259)

## [3.10.0] - 2026-05-19

### Changed

- Upgrade to libzim 9.7.0 (#254)

## [3.9.0] - 2026-03-24

### Added

- Added Changelog to docs (#227)

### Changed

- Upgrade to libzim 9.5.1 and upgrade other Python dependencies, especially Cython 3.2.4 (#250)

### Fixed

- Fixed broken links in docs (#246)

## [3.8.0] - 2025-11-14

### Changed

- Maintenance upgrades (#237):
  - Drop support of Python 3.9
  - Add support for Python 3.14
  - Upgrade dependencies, especially Cython 3.1.6
  - Upgrade supported macOS to 14.0+ (instead of 13.0+)
  - Add support for free-threaded CPython (3.13 and 3.14)
  - Upgrade Github CI Actions
  - Run tests on minimum supported platforms + more recent stable ones
- Fix various Cython warning and deprecation notices (#239)
- libzim 9.4.0 Cache Control API
  - remove `Archive.dirent_lookup_cache_max_size`, does not exists anymore in libzim
  - move `Archive.cluster_cache_max_size` and `Archive.cluster_cache_current_size` to methods outside of `Archive` object: `get_cluster_cache_max_size`, `set_cluster_cache_max_size`, `get_cluster_cache_current_size` (size is now in bytes)
  - deprecate usage of `get_illustration_sizes()`


## [3.7.0] - 2025-04-18

### Added

- Set up documentation using `mkdocs`, published on readthedocs.com (#186)
- `Archive.get_random_entry()`
- libzim 9.3.0 Cache Control API:
  - `Archive.cluster_cache_max_size`
  - `Archive.cluster_cache_current_size`
  - `Archive.dirent_cache_max_size`
  - `Archive.dirent_cache_current_size`
  - `Archive.dirent_lookup_cache_max_size`

### Changed

- Using C++ libzim 9.3.0-1

## [3.6.0] - 2024-10-15

### Added

- Support for Python 3.13 (#208)

### Changed

- `delocate` dependency only required on Windows platform

## [3.5.0]

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
