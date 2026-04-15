subinclude("//build_defs:neovim", "//build_defs:nvim_versions")

neovim_test(
    name = "please_spec",
    src = "please_spec.lua",
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "third_party/please/plz",
    },
    nvim_versions = NVIM_VERSIONS,
    deps = [
        ":log_handler",
        ":temptree",
        "//:please",
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

neovim_library(
    name = "temptree",
    srcs = ["temptree.lua"],
)

neovim_library(
    name = "log_handler",
    srcs = ["log_handler.lua"],
)
