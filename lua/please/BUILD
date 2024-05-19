neovim_lua_module(
    name = "command",
    srcs = ["command.lua"],
    deps = [
        ":logging",
    ],
)

neovim_lua_module(
    name = "debug",
    srcs = ["debug.lua"],
    deps = [
        ":logging",
        ":plz",
        ":query",
        "//third_party/neovim:nvim_dap",
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
        ":logging",
        "//lua",
        "//lua/please/runners:popup",
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
        ":logging",
        ":plz",
    ],
)

neovim_lua_module(
    name = "runner",
    srcs = ["Runner.lua"],
    deps = [
        ":logging",
    ],
)
