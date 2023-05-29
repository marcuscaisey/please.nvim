neovim_lua_module(
    name = "command",
    srcs = ["command.lua"],
    deps = [
        ":logging",
    ],
)

neovim_lua_module(
    name = "cursor",
    srcs = ["cursor.lua"],
)

neovim_lua_module(
    name = "debug",
    srcs = ["debug.lua"],
    deps = [
        ":logging",
        ":query",
        ":utils",
        "//third_party/neovim:nvim_dap",
        "//third_party/neovim:plenary",
    ],
)

neovim_lua_module(
    name = "logging",
    srcs = ["logging.lua"],
)

neovim_lua_module(
    name = "parsing",
    srcs = ["parsing.lua"],
    deps = [
        ":cursor",
        ":logging",
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:nvim_treesitter",
        "//third_party/neovim:plenary",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

neovim_lua_module(
    name = "parsingv2",
    srcs = [
        "parsingv2.lua",
    ],
    deps = [
        ":cursor",
        ":logging",
        "//third_party/neovim:go_tree_sitter_parser",
    ],
)

neovim_lua_module(
    name = "plugin",
    srcs = ["plugin.lua"],
    deps = [
        ":command",
        ":debug",
        ":logging",
        "//lua",
        "//lua/please/runners:popup",
    ],
)

neovim_lua_module(
    name = "query",
    srcs = ["query.lua"],
    deps = [
        ":logging",
        ":utils",
        "//third_party/neovim:plenary",
    ],
)

neovim_lua_module(
    name = "utils",
    srcs = ["utils.lua"],
)
