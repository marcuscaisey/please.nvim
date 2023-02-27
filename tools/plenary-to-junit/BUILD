pkg = package_name()

go_binary(
    name = "plenary-to-junit",
    srcs = glob(
        ["*.go"],
        exclude = ["*_test.go"],
    ),
    visibility = ["PUBLIC"],
)

gentest(
    name = "test",
    data = [
        "testdata/test_output.xml",
    ],
    test_cmd = "diff --color=always tools/plenary-to-junit/testdata/test_output.xml <($TOOLS_RUNNER | $TOOLS_PLENARY_TO_JUNIT)",
    test_tools = {
        "runner": ":_test_spec#runner",
        "plenary_to_junit": ":plenary-to-junit",
    },
    no_test_output = True,
)

neovim_test(
    name = "test_spec",
    test_file = "testdata/test_spec.lua",
)

sh_cmd(
    name = "generate_test_output",
    cmd = [
        "export root=$(plz query reporoot)",
        "cd $(mktemp -d)",
        f"\\\$root/$(out_location :_test_spec#runner) | \\\$root/$(out_location :plenary-to-junit) > \\\$root/{pkg}/testdata/test_output.xml",
    ],
    deps = [
        ":plenary-to-junit",
        ":_test_spec#runner",
    ],
)
