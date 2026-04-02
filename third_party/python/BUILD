subinclude("///python//build_defs:python")

pip_library(
    name = "requests",
    licences = ["Apache-2.0"],
    version = "2.28.1",
    visibility = ["PUBLIC"],
    deps = [
        ":certifi",
        ":charset_normalizer",
        ":idna",
        ":urllib3",
    ],
)

pip_library(
    name = "charset_normalizer",
    licences = ["MIT"],
    version = "2.1.0",
)

pip_library(
    name = "idna",
    licences = ["BSD-3-Clause"],
    version = "3.3",
)

pip_library(
    name = "urllib3",
    licences = ["MIT"],
    version = "1.26.11",
)

pip_library(
    name = "certifi",
    licences = ["Mozilla Public License 2.0"],
    version = "2022.6.15",
)
