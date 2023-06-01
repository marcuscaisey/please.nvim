python_test(
    name = "pythonpkg_test",
    srcs = ["pythonpkg_test.py"],
)

python_binary(
    name = "ping",
    main = "ping.py",
    deps = [
        "//third_party/python:requests",
    ],
)
