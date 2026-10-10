import pytest

from libzim.illustration import (  # pyright: ignore [reportMissingModuleSource]
    IllustrationInfo,
)


class TestIllustrationInfo:

    def test_default_construction(self):
        """Test creating an IllustrationInfo with defaults."""
        info = IllustrationInfo()
        assert info.width == 0
        assert info.height == 0
        assert info.scale == 1.0
        assert info.extra_attributes == {}

    def test_construction_with_parameters(self):
        """Test creating an IllustrationInfo with parameters."""
        info = IllustrationInfo(width=48, height=48, scale=2.0)
        assert info.width == 48
        assert info.height == 48
        assert info.scale == 2.0
        assert info.extra_attributes == {}

    def test_non_square_illustration(self):
        """Test creating a non-square illustration."""
        info = IllustrationInfo(width=128, height=64, scale=1.5)
        assert info.width == 128
        assert info.height == 64
        assert info.scale == 1.5

    def test_property_setters(self):
        """Test setting properties after construction."""
        info = IllustrationInfo()
        info.width = 96
        info.height = 48
        info.scale = 3.0
        assert info.width == 96
        assert info.height == 48
        assert info.scale == 3.0

    def test_extra_attributes_contruction(self):
        """Test setting extra attributes in constructor."""
        info = IllustrationInfo(48, 48, 1.0, {"foo": "bar", "baz": "qux"})
        assert info.extra_attributes == {"foo": "bar", "baz": "qux"}

    def test_extra_attributes_setter(self):
        """Test setting extra attributes."""
        info = IllustrationInfo(48, 48, 1.0)
        info.extra_attributes = {"foo": "bar", "baz": "qux"}
        assert info.extra_attributes == {"foo": "bar", "baz": "qux"}

    def test_extra_attributes_not_directly_mutable(self):
        """Test that direct mutation of extra_attributes doesn't persist.

        The extra_attributes property returns a new dict each time it's accessed,
        so direct mutation operations like .update() or direct assignment don't work.
        You must use the setter to update the attributes.
        """
        info = IllustrationInfo(48, 48, 1.0)
        info.extra_attributes = {"original": "value"}

        # This won't work - modifying the returned dict doesn't affect underlying data
        info.extra_attributes.update({"new": "item"})
        assert info.extra_attributes == {"original": "value"}  # "new" was not added

        # This won't work either - item assignment on the returned dict
        info.extra_attributes["another"] = "value"
        assert info.extra_attributes == {"original": "value"}  # "another" was not added

        # The correct way is to use the setter with the full dict
        current = info.extra_attributes
        current.update({"new": "item"})
        info.extra_attributes = current
        assert info.extra_attributes == {"original": "value", "new": "item"}

        # Or create a new dict directly
        info.extra_attributes = {"original": "value", "new": "item", "another": "value"}
        assert info.extra_attributes == {
            "original": "value",
            "new": "item",
            "another": "value",
        }

    def test_as_metadata_item_name(self):
        """Test converting IllustrationInfo to metadata item name."""
        info = IllustrationInfo(48, 48, 1.0)
        name = info.as_metadata_item_name()
        # Should be in format like "Illustration_48x48@1"
        assert "48" in name
        assert "Illustration" in name

    def test_as_metadata_item_name_with_scale(self):
        """Test metadata item name includes scale."""
        info = IllustrationInfo(48, 48, 2.0)
        name = info.as_metadata_item_name()
        assert "48" in name
        assert "2" in name or "@2" in name  # Scale should be included

    def test_from_metadata_item_name(self):
        """Test parsing metadata item name into IllustrationInfo."""
        # First create an info and convert to name
        original_info = IllustrationInfo(48, 48, 2.0)
        name = original_info.as_metadata_item_name()

        # Parse it back
        parsed_info = IllustrationInfo.from_metadata_item_name(name)
        assert parsed_info.width == 48
        assert parsed_info.height == 48
        assert parsed_info.scale == 2.0

    def test_from_metadata_item_name_square(self):
        """Test parsing square illustration metadata name."""
        original = IllustrationInfo(96, 96, 1.0)
        name = original.as_metadata_item_name()
        parsed = IllustrationInfo.from_metadata_item_name(name)
        assert parsed.width == 96
        assert parsed.height == 96
        assert parsed.scale == 1.0

    def test_repr(self):
        """Test __repr__ returns useful string."""
        info = IllustrationInfo(48, 48, 2.0)
        repr_str = repr(info)
        assert "IllustrationInfo" in repr_str
        assert "48" in repr_str
        assert "2" in repr_str or "2.0" in repr_str

    def test_equality(self):
        """Test __eq__ compares IllustrationInfo correctly."""
        info1 = IllustrationInfo(48, 48, 2.0)
        info2 = IllustrationInfo(48, 48, 2.0)
        info3 = IllustrationInfo(48, 48, 1.0)
        info4 = IllustrationInfo(96, 96, 2.0)

        assert info1 == info2
        assert info1 != info3  # Different scale
        assert info1 != info4  # Different dimensions
        assert info1 != "not an IllustrationInfo"
        assert info1 != 42

    def test_equality_with_extra_attributes(self):
        """Test equality considers extra attributes."""
        info1 = IllustrationInfo(48, 48, 1.0)
        info2 = IllustrationInfo(48, 48, 1.0)
        info1.extra_attributes = {"key": "value"}
        info2.extra_attributes = {"key": "value"}
        assert info1 == info2

        info3 = IllustrationInfo(48, 48, 1.0)
        info3.extra_attributes = {"different": "value"}
        assert info1 != info3

    def test_roundtrip_conversion(self):
        """Test converting to and from metadata item name preserves data."""
        original = IllustrationInfo(64, 32, 1.5)
        name = original.as_metadata_item_name()
        restored = IllustrationInfo.from_metadata_item_name(name)

        assert restored.width == original.width
        assert restored.height == original.height
        assert restored.scale == original.scale


class TestIllustrationInfoEdgeCases:
    """Test edge cases and error handling."""

    def test_from_metadata_item_name_invalid(self):
        """Test parsing invalid metadata item names raises error."""
        with pytest.raises(RuntimeError):
            IllustrationInfo.from_metadata_item_name("invalid_name")

    def test_from_metadata_item_name_empty(self):
        """Test parsing empty string raises error."""
        with pytest.raises(RuntimeError):
            IllustrationInfo.from_metadata_item_name("")

    def test_zero_dimensions(self):
        """Test creating illustration with zero dimensions."""
        info = IllustrationInfo(0, 0, 1.0)
        assert info.width == 0
        assert info.height == 0

    def test_fractional_scale(self):
        """Test creating illustration with fractional scale."""
        info = IllustrationInfo(48, 48, 1.5)
        assert info.scale == 1.5

    def test_very_large_dimensions(self):
        """Test creating illustration with large dimensions."""
        info = IllustrationInfo(4096, 4096, 1.0)
        assert info.width == 4096
        assert info.height == 4096
