
# Setup

```bash
     $ docker-compose build
    $ docker-compose run libzim /bin/bash
```
```bash
python setup.py build_ext -i
python tests/test_pyzim.py

# or

./rebuild.sh
./run_tests
```

Example:

import pyzim

zim_file_path = "/opt/python-libzim/tests/wikipedia_es_physics_mini.zim"
zim_reader = pyzim.ZimReader(zim_file_path)