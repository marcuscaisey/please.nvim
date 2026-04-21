subinclude("///python//build_defs:python")

python_binary(
    name = "check_neovim_toolchain_versions",
    main = "check_neovim_toolchain_versions.py",
    deps = [
        "//third_party/python:requests",
    ],
)

python_binary(
    name = "neovim_toolchains",
    main = "neovim_toolchains.py",
)
