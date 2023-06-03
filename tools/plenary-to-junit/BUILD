def plenary_to_junit_test(name, test_target):
    test_target_pkg, test_target_name = decompose(test_target)
    snapshot_target = "//" + test_target_pkg + ":" + test_target_name.removesuffix("_spec") + "_snapshot"
    return gentest(
        name = name,
        data = [snapshot_target],
        no_test_output = True,
        test_cmd = f"diff --color=always $(location {snapshot_target}) <($TOOLS_RUNNER 2>&1 | $TOOLS_PLENARY_TO_JUNIT)",
        test_tools = {
            "runner": "//" + test_target_pkg + ":" + tag(test_target_name, "runner"),
            "plenary_to_junit": ":plenary-to-junit",
        },
    )

go_binary(
    name = "plenary-to-junit",
    srcs = glob(
        ["*.go"],
        exclude = ["*_test.go"],
    ),
    visibility = ["PUBLIC"],
)

plenary_to_junit_test(
    name = "test_pass_fail_skip",
    test_target = "//tools/plenary-to-junit/testdata:pass_fail_skip_spec",
)

plenary_to_junit_test(
    name = "test_error",
    test_target = "//tools/plenary-to-junit/testdata:error_spec",
)

plenary_to_junit_test(
    name = "test_error_after_tests",
    test_target = "//tools/plenary-to-junit/testdata:error_after_tests_spec",
)

plenary_to_junit_test(
    name = "test_error_in_describe",
    test_target = "//tools/plenary-to-junit/testdata:error_in_describe_spec",
)

plenary_to_junit_test(
    name = "test_error_in_describe_with_failure",
    test_target = "//tools/plenary-to-junit/testdata:error_in_describe_with_failure_spec",
)

plenary_to_junit_test(
    name = "test_empty",
    test_target = "//tools/plenary-to-junit/testdata:empty_spec",
)

plenary_to_junit_test(
    name = "test_stdout",
    test_target = "//tools/plenary-to-junit/testdata:stdout_spec",
)

plenary_to_junit_test(
    name = "test_nvim_startup",
    test_target = "//tools/plenary-to-junit/testdata:nvim_startup_spec",
)
