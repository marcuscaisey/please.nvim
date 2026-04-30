subinclude("///go//build_defs:go")

go_test(
    name = "tests",
    srcs = [
        "example_test.go",
        "suite_in_another_file_test.go",
    ],
    external = True,
    labels = ["manual"],
    deps = ["///third_party/go/github.com_stretchr_testify//suite"],
)
