neovim_test(
    name = "please_spec_0_8_0",
    test_file = "please_spec.lua",
    deps = [
        "//:please",
        "//lua/please:cursor",
        "//tests/utils:mock",
        "//tests/utils:temptree",
    ],
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "$TMP_DIR/third_party/please/plz",
    },
    nvim = "//third_party/neovim:toolchain_0_8_0|nvim",
)

neovim_test(
    name = "please_spec_0_9_1",
    test_file = "please_spec.lua",
    deps = [
        "//:please",
        "//lua/please:cursor",
        "//tests/utils:mock",
        "//tests/utils:temptree",
    ],
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "$TMP_DIR/third_party/please/plz",
    },
    nvim = "//third_party/neovim:toolchain_0_9_1|nvim",
)
