subinclude("//build_defs:neovim")

neovim_test(
    name = "parsing_spec",
    src = "parsing_spec.lua",
    data = ["//third_party/please:plz"],
    env = {"PLEASE_NVIM_PLZ": "third_party/please/plz"},
    deps = [
        "//:please",
        "//tests:log_handler",
        "//tests:temptree",
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

neovim_test(
    name = "parsing_spec_legacy_go_parser",
    src = "parsing_spec.lua",
    data = ["//third_party/please:plz"],
    env = {"PLEASE_NVIM_PLZ": "third_party/please/plz"},
    deps = [
        "//:please",
        "//tests:log_handler",
        "//tests:temptree",
        "//third_party/neovim:go_tree_sitter_parser_0_23",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)
