neovim_plugin(
    name = "please",
    help_srcs = [
        "lua/please.lua",
        "lua/please/logging.lua",
    ],
    deps = [
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:nvim_dap",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

export_file(
    name = "gomod",
    src = "go.mod",
    visibility = ["PUBLIC"],
)
