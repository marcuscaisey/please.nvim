neovim_plugin(
    name = "please",
    help_opts = [
        "--layout mini",
        "--prefix-func",
    ],
    help_srcs = [
        "//lua:lua",
        "//lua/please/runners:popup",
        "//lua/please:logging",
    ],
    deps = [
        "//lua",
        "//plugin",
    ],
)

export_file(
    name = "gomod",
    src = "go.mod",
    visibility = ["PUBLIC"],
)
