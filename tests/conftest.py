import base64

import pytest


@pytest.fixture(scope="module")
def favicon_data():
    return base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQ"
        "ImWO4ISn6HwAE2QIGKsd69QAAAABJRU5ErkJggg=="
    )
