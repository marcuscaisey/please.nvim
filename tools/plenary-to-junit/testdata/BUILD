def neovim_test_and_snapshot(name, test_file):
    test_rule = neovim_test(
        name = name,
        labels = ["manual"],
        test_file = test_file,
    )

    snapshot_name = name.removesuffix("_spec") + "_snapshot"
    snapshot_output = f"{snapshot_name}.xml"
    export_file(
        name = snapshot_name,
        src = snapshot_output,
        visibility = ["//tools/plenary-to-junit/..."],
    )

    pkg = package_name()
    runner_target = ":" + tag(name, "runner")
    sh_cmd(
        name = f"generate_{snapshot_name}",
        cmd = [
            "export root=$(plz query reporoot)",
            "cd $(mktemp -d)",
            f"\\\$root/$(out_location {runner_target}) | \\\$root/$(out_location //tools/plenary-to-junit) | tee \\\$root/{pkg}/{snapshot_output}",
        ],
        labels = ["generate_snapshot"],
        deps = [
            runner_target,
            "//tools/plenary-to-junit",
        ],
    )

sh_cmd(
    name = "generate_snapshots",
    cmd = "plz run parallel //tools/plenary-to-junit/testdata/... --include generate_snapshot",
)

neovim_test_and_snapshot(
    name = "pass_fail_skip_spec",
    test_file = "pass_fail_skip_spec.lua",
)

neovim_test_and_snapshot(
    name = "error_spec",
    test_file = "error_spec.lua",
)

neovim_test_and_snapshot(
    name = "error_after_tests_spec",
    test_file = "error_after_tests_spec.lua",
)

neovim_test_and_snapshot(
    name = "error_in_describe_spec",
    test_file = "error_in_describe_spec.lua",
)

neovim_test_and_snapshot(
    name = "error_in_describe_with_failure_spec",
    test_file = "error_in_describe_with_failure_spec.lua",
)

neovim_test_and_snapshot(
    name = "empty_spec",
    test_file = "empty_spec.lua",
)

neovim_test_and_snapshot(
    name = "stdout_spec",
    test_file = "stdout_spec.lua",
)
