subinclude("//build_defs:neovim")

neovim_toolchain(
    name = "toolchain",
    version = "v0.11.1",
)

github_neovim_tree_sitter_parser(
    name = "go_tree_sitter_parser",
    lang = "go",
    repo = "tree-sitter/tree-sitter-go",
    revision = "v0.25.0",
)

github_neovim_tree_sitter_parser(
    name = "go_tree_sitter_parser_0_23",
    lang = "go",
    repo = "tree-sitter/tree-sitter-go",
    revision = "v0.23.4",
)

github_neovim_tree_sitter_parser(
    name = "python_tree_sitter_parser",
    lang = "python",
    repo = "tree-sitter/tree-sitter-python",
    revision = "710796b8b877a970297106e5bbc8e2afa47f86ec",
)
