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
        ":future",
        ":logging",
        ":plz",
        ":query",
        ":utils",
        "//third_party/neovim:nvim_dap",
    ],
)

neovim_lua_module(
    name = "future",
    srcs = ["future.lua"],
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
        ":future",
        ":logging",
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

neovim_lua_module(
    name = "plugin",
    srcs = ["plugin.lua"],
    deps = [
        ":command",
        ":debug",
        ":future",
        ":logging",
        "//lua",
        "//lua/please/runners:popup",
        "//third_party/neovim:nvim_treesitter",
    ],
)

neovim_lua_module(
    name = "plz",
    srcs = ["plz.lua"],
)

neovim_lua_module(
    name = "query",
    srcs = ["query.lua"],
    deps = [
        ":future",
        ":logging",
        ":plz",
        ":utils",
    ],
)

neovim_lua_module(
    name = "utils",
    srcs = ["utils.lua"],
)
