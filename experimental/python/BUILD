python_test(
    name = "example_test",
    srcs = ["example_test.py"],
    labels = ["manual"],
)

python_binary(
    name = "ping",
    main = "ping.py",
    deps = [
        "//third_party/python:requests",
    ],
)
