subinclude("//build_defs:neovim")

neovim_plugin(
    name = "please",
    help_srcs = [
        "lua/please.lua",
    ],
)

export_file(
    name = "gomod",
    src = "go.mod",
    visibility = ["PUBLIC"],
)
