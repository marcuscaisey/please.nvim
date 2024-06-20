neovim_test(
    name = "please_spec",
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "third_party/please/plz",
    },
    test_file = "please_spec.lua",
    deps = [
        ":temptree",
        "//:please",
    ],
)

neovim_lua_module(
    name = "temptree",
    srcs = ["temptree.lua"],
)
