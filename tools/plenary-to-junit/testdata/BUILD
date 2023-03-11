def generate_test_snapshot(name, test_target, output):
    pkg = package_name()
    test_target_pkg, test_target_name = decompose(test_target)
    runner_target = ":" + tag(test_target.lstrip(":"), "runner")
    export_file(
        name = output.rstrip(".xml"),
        src = output,
        visibility = ["//tools/plenary-to-junit/..."],
    )
    return sh_cmd(
        name = name,
        cmd = [
            "export root=$(plz query reporoot)",
            "cd $(mktemp -d)",
            f"\\\$root/$(out_location {runner_target}) | \\\$root/$(out_location //tools/plenary-to-junit) | tee \\\$root/{pkg}/{output}",
        ],
        deps = [
            runner_target,
            "//tools/plenary-to-junit",
        ],
    )

neovim_test(
    name = "pass_fail_skip_spec",
    labels = ["manual"],
    test_file = "pass_fail_skip_spec.lua",
)

generate_test_snapshot(
    name = "generate_pass_fail_skip_snapshot",
    output = "pass_fail_skip_snapshot.xml",
    test_target = ":pass_fail_skip_spec",
)

neovim_test(
    name = "error_spec",
    labels = ["manual"],
    test_file = "error_spec.lua",
)

generate_test_snapshot(
    name = "generate_error_spec",
    output = "error_snapshot.xml",
    test_target = ":error_spec",
)

neovim_test(
    name = "error_after_tests_spec",
    labels = ["manual"],
    test_file = "error_after_tests_spec.lua",
)

generate_test_snapshot(
    name = "generate_error_after_tests_snapshot",
    output = "error_after_tests_snapshot.xml",
    test_target = ":error_after_tests_spec",
)

neovim_test(
    name = "error_in_describe_spec",
    labels = ["manual"],
    test_file = "error_in_describe_spec.lua",
)

generate_test_snapshot(
    name = "generate_error_in_describe_snapshot",
    output = "error_in_describe_snapshot.xml",
    test_target = ":error_in_describe_spec",
)

neovim_test(
    name = "error_in_describe_with_failure_spec",
    labels = ["manual"],
    test_file = "error_in_describe_with_failure_spec.lua",
)

generate_test_snapshot(
    name = "generate_error_in_describe_with_failure_snapshot",
    output = "error_in_describe_with_failure_snapshot.xml",
    test_target = ":error_in_describe_with_failure_spec",
)

neovim_test(
    name = "empty_spec",
    labels = ["manual"],
    test_file = "empty_spec.lua",
)

generate_test_snapshot(
    name = "generate_empty_snapshot",
    output = "empty_snapshot.xml",
    test_target = ":empty_spec",
)
