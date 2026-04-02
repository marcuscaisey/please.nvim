subinclude("//build_defs:neovim")

neovim_test(
    name = "parsing_spec",
    src = "parsing_spec.lua",
    deps = [
        "//:please",
        "//tests:temptree",
        "//third_party/neovim:go_tree_sitter_parser",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)

neovim_test(
    name = "parsing_spec_go_tree_sitter_parser_0_23",
    src = "parsing_spec.lua",
    deps = [
        "//:please",
        "//tests:temptree",
        "//third_party/neovim:go_tree_sitter_parser_0_23",
        "//third_party/neovim:python_tree_sitter_parser",
    ],
)
