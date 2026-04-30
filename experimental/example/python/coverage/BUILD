subinclude("///python//build_defs:python")

python_test(
    name = "coverage_test",
    srcs = ["coverage_test.py"],
    labels = ["manual"],
    deps = [":coverage"],
)

python_library(
    name = "coverage",
    srcs = [
        "greetings.py",
        "maths.py",
    ],
)
