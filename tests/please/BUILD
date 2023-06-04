neovim_test(
    name = "parsing_spec_0_8_0",
    test_file = "parsing_spec.lua",
    deps = [
        "//lua/please:cursor",
        "//lua/please:parsing",
        "//tests/utils:temptree",
    ],
    nvim = "//third_party/neovim:toolchain_0_8_0|nvim",
)

neovim_test(
    name = "parsing_spec_0_9_1",
    test_file = "parsing_spec.lua",
    deps = [
        "//lua/please:cursor",
        "//lua/please:parsing",
        "//tests/utils:temptree",
    ],
    nvim = "//third_party/neovim:toolchain_0_9_1|nvim",
)

neovim_test(
    name = "query_spec",
    test_file = "query_spec.lua",
    deps = [
        "//lua/please:query",
        "//tests/utils:temptree",
    ],
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "$TMP_DIR/third_party/please/plz",
    },
)
