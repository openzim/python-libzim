#!/usr/bin/env python3

# This file is part of python-libzim
# (see https://github.com/libzim/python-libzim)
#
# Copyright (c) 2025 Benoit Arnaud <benoit@kymeria.fr>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

import pytest

from libzim.illustration import (  # pyright: ignore [reportMissingModuleSource]
    IllustrationInfo,
)
from libzim.reader import Archive  # pyright: ignore [reportMissingModuleSource]
from libzim.writer import Creator  # pyright: ignore [reportMissingModuleSource]


@pytest.fixture(scope="function")
def zim_with_varied_illustrations(tmp_path, favicon_data):
    """Create a ZIM file with various illustration sizes and scales."""
    fpath = tmp_path / "test_illustrations.zim"
    with Creator(fpath) as c:
        c.add_metadata("Title", "Test ZIM")

        # Add multiple illustrations with different dimensions and scales
        # 48x48 at different scales
        c.add_illustration(IllustrationInfo(48, 48, 1.0), favicon_data)
        c.add_illustration(IllustrationInfo(48, 48, 2.0), favicon_data)
        c.add_illustration(IllustrationInfo(48, 48, 3.0), favicon_data)

        # 96x96 at different scales
        c.add_illustration(IllustrationInfo(96, 96, 1.0), favicon_data)
        c.add_illustration(IllustrationInfo(96, 96, 2.0), favicon_data)

        # Non-square illustrations
        c.add_illustration(IllustrationInfo(128, 64, 1.0), favicon_data)
        c.add_illustration(IllustrationInfo(64, 128, 1.0), favicon_data)

        # Large illustration
        c.add_illustration(IllustrationInfo(256, 256, 1.0), favicon_data)

    return fpath


class TestArchiveGetIllustrationInfos:
    """Test Archive.get_illustration_infos() method."""

    def test_get_all_illustration_infos(self, zim_with_varied_illustrations):
        """Test getting all illustration infos without filtering."""
        zim = Archive(zim_with_varied_illustrations)
        infos = zim.get_illustration_infos()

        # Should return all 8 illustrations
        assert len(infos) == 8

        # All should be IllustrationInfo instances
        assert all(isinstance(info, IllustrationInfo) for info in infos)

        # Verify we have expected dimensions
        dims = {(info.width, info.height) for info in infos}
        assert (48, 48) in dims
        assert (96, 96) in dims
        assert (128, 64) in dims
        assert (64, 128) in dims
        assert (256, 256) in dims

    def test_get_illustration_infos_filter_48x48(self, zim_with_varied_illustrations):
        """Test filtering illustrations by 48x48 dimensions."""
        zim = Archive(zim_with_varied_illustrations)
        # Get all 48x48 illustrations with minimum scale 1.0
        infos = zim.get_illustration_infos(width=48, height=48, min_scale=1.0)

        # Should have 3 illustrations: @1, @2, @3
        assert len(infos) >= 3

        # All should be 48x48
        assert all(info.width == 48 and info.height == 48 for info in infos)

        # All should have scale >= 1.0
        assert all(info.scale >= 1.0 for info in infos)

    def test_get_illustration_infos_filter_min_scale(
        self, zim_with_varied_illustrations
    ):
        """Test filtering by minimum scale."""
        zim = Archive(zim_with_varied_illustrations)
        # Get 48x48 illustrations with scale >= 2.0
        infos = zim.get_illustration_infos(width=48, height=48, min_scale=2.0)

        # Should have at least 2: @2 and @3
        assert len(infos) >= 2

        # All should be 48x48
        assert all(info.width == 48 and info.height == 48 for info in infos)

        # All should have scale >= 2.0
        assert all(info.scale >= 2.0 for info in infos)

    def test_get_illustration_infos_filter_high_scale(
        self, zim_with_varied_illustrations
    ):
        """Test filtering with high minimum scale."""
        zim = Archive(zim_with_varied_illustrations)
        # Get 48x48 illustrations with scale >= 3.0
        infos = zim.get_illustration_infos(width=48, height=48, min_scale=3.0)

        # Should have at least 1: @3
        assert len(infos) >= 1

        # All should have scale >= 3.0
        assert all(info.scale >= 3.0 for info in infos)

    def test_get_illustration_infos_filter_96x96(self, zim_with_varied_illustrations):
        """Test filtering for 96x96 illustrations."""
        zim = Archive(zim_with_varied_illustrations)
        infos = zim.get_illustration_infos(width=96, height=96, min_scale=1.0)

        # Should have 2: @1 and @2
        assert len(infos) >= 2

        # All should be 96x96
        assert all(info.width == 96 and info.height == 96 for info in infos)

    def test_get_illustration_infos_no_match(self, zim_with_varied_illustrations):
        """Test filtering with no matching illustrations."""
        zim = Archive(zim_with_varied_illustrations)
        # Request dimensions that don't exist
        infos = zim.get_illustration_infos(width=999, height=999, min_scale=1.0)

        # Should return empty list
        assert len(infos) == 0

    def test_get_illustration_infos_partial_args_error(
        self, zim_with_varied_illustrations
    ):
        """Test that providing partial filter arguments raises error."""
        zim = Archive(zim_with_varied_illustrations)

        # Only width should raise error
        with pytest.raises(ValueError, match=r"Either provide all of.*or none"):
            zim.get_illustration_infos(width=48)

        # Only height should raise error
        with pytest.raises(ValueError, match=r"Either provide all of.*or none"):
            zim.get_illustration_infos(height=48)

        # Width and height but no min_scale should raise error
        with pytest.raises(ValueError, match=r"Either provide all of.*or none"):
            zim.get_illustration_infos(width=48, height=48)

        # Only min_scale should raise error
        with pytest.raises(ValueError, match=r"Either provide all of.*or none"):
            zim.get_illustration_infos(min_scale=1.0)


class TestArchiveGetIllustrationItem:
    """Test Archive.get_illustration_item() with IllustrationInfo."""

    def test_get_illustration_item_with_info(
        self, zim_with_varied_illustrations, favicon_data
    ):
        """Test getting illustration item using IllustrationInfo."""
        zim = Archive(zim_with_varied_illustrations)
        infos = zim.get_illustration_infos()

        # Get item for each illustration
        for info in infos:
            item = zim.get_illustration_item(info=info)
            assert bytes(item.content) == favicon_data
            # Verify path contains the illustration metadata name
            assert "Illustration" in item.path

    def test_get_illustration_item_specific_scale(
        self, zim_with_varied_illustrations, favicon_data
    ):
        """Test getting specific scale illustration."""
        zim = Archive(zim_with_varied_illustrations)

        # Get the 48x48@2 illustration specifically
        info = IllustrationInfo(48, 48, 2.0)
        item = zim.get_illustration_item(info=info)
        assert bytes(item.content) == favicon_data

    def test_get_illustration_item_nonexistent(self, zim_with_varied_illustrations):
        """Test getting non-existent illustration raises error."""
        zim = Archive(zim_with_varied_illustrations)

        # Try to get illustration that doesn't exist
        info = IllustrationInfo(999, 999, 1.0)
        with pytest.raises(KeyError):
            zim.get_illustration_item(info=info)

    def test_get_illustration_item_old_api_still_works(
        self, zim_with_varied_illustrations, favicon_data
    ):
        """Test that old API (size parameter) still works."""
        zim = Archive(zim_with_varied_illustrations)

        # Old API with size should work for @1 scale illustrations
        item = zim.get_illustration_item(size=48)
        assert bytes(item.content) == favicon_data

        item = zim.get_illustration_item(size=96)
        assert bytes(item.content) == favicon_data


class TestDeprecationWarnings:
    """Test deprecation warnings for old API."""

    def test_get_illustration_sizes_deprecated(self, zim_with_varied_illustrations):
        """Test that get_illustration_sizes() emits deprecation warning."""
        zim = Archive(zim_with_varied_illustrations)

        with pytest.warns(
            DeprecationWarning, match="get_illustration_sizes.*deprecated"
        ):
            sizes = zim.get_illustration_sizes()
            # Should still work despite deprecation
            assert isinstance(sizes, set)
            # Should contain sizes for @1 scale illustrations
            assert 48 in sizes or 96 in sizes


class TestEmptyArchive:
    """Test illustration methods on archives with no illustrations."""

    def test_get_illustration_infos_empty(self, tmp_path):
        """Test get_illustration_infos on archive with no illustrations."""
        fpath = tmp_path / "empty_illustrations.zim"
        with Creator(fpath) as c:
            c.add_metadata("Title", "Test ZIM")

        zim = Archive(fpath)
        infos = zim.get_illustration_infos()
        assert len(infos) == 0

    def test_get_illustration_item_empty(self, tmp_path):
        """Test get_illustration_item on archive with no illustrations."""
        fpath = tmp_path / "empty_illustrations.zim"
        with Creator(fpath) as c:
            c.add_metadata("Title", "Test ZIM")

        zim = Archive(fpath)
        with pytest.raises(KeyError):
            zim.get_illustration_item()

    def test_has_illustration_empty(self, tmp_path):
        """Test has_illustration on archive with no illustrations."""
        fpath = tmp_path / "empty_illustrations.zim"
        with Creator(fpath) as c:
            c.add_metadata("Title", "Test ZIM")

        zim = Archive(fpath)
        assert zim.has_illustration() is False
        assert zim.has_illustration(48) is False
