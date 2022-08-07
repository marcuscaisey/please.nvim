python_library(
    name = "add",
    srcs = ["add.py"],
)

python_test(
    name = "add_test",
    srcs = ["add_test.py"],
    deps = [":add"],
)

python_binary(
    name = "ping",
    main = "ping.py",
    deps = [
        "//third_party/python:requests",
    ]
)
