neovim_lua_module(
    name = "runners",
    srcs = [
        "init.lua",
    ],
    deps = [
        ":popup",
        ":tmux",
    ],
)

neovim_lua_module(
    name = "popup",
    srcs = ["popup.lua"],
    deps = [
        "//lua/please:cursor",
        "//lua/please:logging",
        "//third_party/neovim:plenary",
    ],
)

neovim_lua_module(
    name = "tmux",
    srcs = ["tmux.lua"],
    deps = [
        "//lua/please:logging",
    ],
)
