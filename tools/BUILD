subinclude("///python//build_defs:python", "///shell//build_defs:shell")

python_binary(
    name = "check_neovim_toolchain_versions",
    main = "check_neovim_toolchain_versions.py",
    deps = [
        "//third_party/python:requests",
    ],
)

sh_binary(
    name = "lint_build_files",
    main = "lint_build_files.sh",
)

python_binary(
    name = "neovim_toolchains",
    main = "neovim_toolchains.py",
)
