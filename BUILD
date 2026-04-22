subinclude("//build_defs:neovim")

neovim_plugin(
    name = "please",
    help_srcs = [
        "lua/please.lua",
    ],
)

filegroup(
    name = "docs",
    srcs = [
        "README.md",
        "doc/please.txt",
    ],
    visibility = ["PUBLIC"],
)

export_file(
    name = "gomod",
    src = "go.mod",
    visibility = ["PUBLIC"],
)
