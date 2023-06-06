go_library(
    name = "gopkg",
    srcs = glob(
        ["*.go"],
        exclude = ["*_test.go"],
    ),
    visibility = ["//gopkg/..."],
    deps = ["//third_party/go:exp"],
)

go_test(
    name = "test",
    srcs = glob(["*_test.go"]),
    external = True,
    labels = ["manual"],
    deps = ["//third_party/go:testify"],
)
