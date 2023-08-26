python_test(
    name = "python_test",
    srcs = ["python_test.py"],
    labels = ["manual"],
)

python_binary(
    name = "ping",
    main = "ping.py",
    deps = [
        "//third_party/python:requests",
    ],
)
