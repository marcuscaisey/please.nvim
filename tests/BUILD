neovim_test(
    name = "please_spec",
    src = "please_spec.lua",
    data = [
        "//third_party/please:plz",
    ],
    env = {
        "PLEASE_NVIM_PLZ": "third_party/please/plz",
    },
    deps = [
        ":temptree",
        "//:please",
    ],
)

neovim_library(
    name = "temptree",
    srcs = ["temptree.lua"],
)
