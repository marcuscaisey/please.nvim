neovim_test(
    name = "parsing_spec",
    test_file = "parsing_spec.lua",
    deps = [
        "//lua/please:cursor",
        "//lua/please:parsing",
        "//lua/please/tests/utils:temptree",
    ],
)

neovim_test(
    name = "please_spec",
    test_file = "please_spec.lua",
    deps = [
        "//:please",
        "//lua/please:cursor",
        "//lua/please/tests/utils:mock",
        "//lua/please/tests/utils:temptree",
    ],
)

neovim_test(
    name = "query_spec",
    test_file = "query_spec.lua",
    deps = [
        "//lua/please:query",
        "//lua/please/tests/utils:temptree",
    ],
)
