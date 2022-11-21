neovim_lua_module(
    name = "lua",
    srcs = ["please.lua"],
    deps = [
        "//lua/please:cursor",
        "//lua/please:debug",
        "//lua/please:logging",
        "//lua/please:parsing",
        "//lua/please:query",
        "//lua/please/runners",
        "//third_party/neovim:plenary",
    ],
)

neovim_generate_docs(
    name = "generate_docs",
    srcs = ["please.lua"],
    opts = [
        "--layout mini",
    ],
    output = "doc/please.txt",
)
