subinclude("///python//build_defs:python", "///shell//build_defs:shell")

python_binary(
    name = "neovim_toolchains",
    main = "neovim_toolchains.py",
)

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

sh_cmd(
    name = "minimal_nvim",
    cmd = "NVIM_APPNAME=nvim-please.nvim plz run '//third_party/neovim:toolchain_stable|nvim' -- -u scripts/minimal_init.lua \"\\\\$@\"",
)

sh_binary(
    name = "record_demo",
    main = "record_demo.sh",
)

sh_binary(
    name = "cast_to_gif",
    main = "cast_to_gif.sh",
)
