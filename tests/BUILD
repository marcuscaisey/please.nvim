neovim_test(
    name = "please_spec",
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "$TMP_DIR/third_party/please/plz",
    },
    test_file = "please_spec.lua",
    deps = [
        "//:please",
        "//lua/please:cursor",
        "//tests/utils:temptree",
    ],
)
