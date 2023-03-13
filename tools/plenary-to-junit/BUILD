def plenary_to_junit_test(name, test_target, snapshot_target):
    test_target_pkg, test_target_name = decompose(test_target)
    return gentest(
        name = name,
        data = [snapshot_target],
        no_test_output = True,
        test_cmd = f"diff --color=always $(location {snapshot_target}) <($TOOLS_RUNNER | $TOOLS_PLENARY_TO_JUNIT)",
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
    snapshot_target = "//tools/plenary-to-junit/testdata:pass_fail_skip_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:pass_fail_skip_spec",
)

plenary_to_junit_test(
    name = "test_error",
    snapshot_target = "//tools/plenary-to-junit/testdata:error_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:error_spec",
)

plenary_to_junit_test(
    name = "test_error_after_tests",
    snapshot_target = "//tools/plenary-to-junit/testdata:error_after_tests_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:error_after_tests_spec",
)

plenary_to_junit_test(
    name = "test_error_in_describe",
    snapshot_target = "//tools/plenary-to-junit/testdata:error_in_describe_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:error_in_describe_spec",
)

plenary_to_junit_test(
    name = "test_error_in_describe_with_failure",
    snapshot_target = "//tools/plenary-to-junit/testdata:error_in_describe_with_failure_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:error_in_describe_with_failure_spec",
)

plenary_to_junit_test(
    name = "test_empty",
    snapshot_target = "//tools/plenary-to-junit/testdata:empty_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:empty_spec",
)

plenary_to_junit_test(
    name = "test_stdout",
    snapshot_target = "//tools/plenary-to-junit/testdata:stdout_snapshot",
    test_target = "//tools/plenary-to-junit/testdata:stdout_spec",
)
