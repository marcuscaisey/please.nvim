subinclude("///python//build_defs:python")

package(
    python = {
        "WHEEL_TOOL": "///python//tools/wheel_resolver",
    },
)

python_wheel(
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

python_wheel(
    name = "charset_normalizer",
    licences = ["MIT"],
    version = "2.1.0",
)

python_wheel(
    name = "idna",
    licences = ["BSD-3-Clause"],
    version = "3.3",
)

python_wheel(
    name = "urllib3",
    licences = ["MIT"],
    version = "1.26.11",
)

python_wheel(
    name = "certifi",
    licences = ["Mozilla Public License 2.0"],
    version = "2022.6.15",
)
