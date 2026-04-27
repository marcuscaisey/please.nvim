subinclude("//build_defs:neovim")

filegroup(
    name = "plugins",
    srcs = [
        ":nvim_dap",
    ],
)

neovim_toolchain(
    name = "toolchain_stable",
    version = "0.12.2",
)

neovim_toolchain(
    name = "toolchain_0_11_latest",
    version = "0.11.7",
)

neovim_toolchain(
    name = "toolchain_0_11_0",
    version = "0.11.0",
)

neovim_tree_sitter_parser(
    name = "go_tree_sitter_parser",
    github_repo = "tree-sitter/tree-sitter-go",
    lang = "go",
    revision = "v0.25.0",
)

neovim_tree_sitter_parser(
    name = "go_tree_sitter_parser_0_23",
    github_repo = "tree-sitter/tree-sitter-go",
    lang = "go",
    revision = "v0.23.4",
)

neovim_tree_sitter_parser(
    name = "python_tree_sitter_parser",
    github_repo = "tree-sitter/tree-sitter-python",
    lang = "python",
    revision = "710796b8b877a970297106e5bbc8e2afa47f86ec",
)

neovim_external_plugin(
    name = "nvim_dap",
    github_repo = "mfussenegger/nvim-dap",
    revision = "45a69eba683a2c448dd9ecfc4de89511f0646b5f",
)
