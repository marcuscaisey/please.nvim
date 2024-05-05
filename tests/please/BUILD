neovim_test(
    name = "parsing_spec_0_8_0",
    nvim = "//third_party/neovim:toolchain_0_8_0|nvim",
    test_file = "parsing_spec.lua",
    deps = [
        "//lua/please:cursor",
        "//lua/please:parsing",
        "//tests/utils:temptree",
    ],
)

neovim_test(
    name = "parsing_spec_0_9_1",
    nvim = "//third_party/neovim:toolchain_0_9_1|nvim",
    test_file = "parsing_spec.lua",
    deps = [
        "//lua/please:cursor",
        "//lua/please:parsing",
        "//lua/please/future",
        "//tests/utils:temptree",
    ],
)

neovim_test(
    name = "query_spec",
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "$TMP_DIR/third_party/please/plz",
    },
    test_file = "query_spec.lua",
    deps = [
        "//lua/please:query",
        "//tests/utils:temptree",
    ],
)
