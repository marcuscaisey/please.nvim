neovim_test(
    name = "please_spec",
    test_file = "please_spec.lua",
    deps = [
        "//:please",
        "//lua/please:cursor",
        "//tests/utils:mock",
        "//tests/utils:temptree",
    ],
    nvim_versions = {
        "0.8.0": "//third_party/neovim:toolchain_0_8_0|nvim",
        "0.9.1": "//third_party/neovim:toolchain_0_9_1|nvim",
    }
)
