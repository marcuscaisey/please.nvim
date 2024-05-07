genrule(
    name =
    "abcdefghijklmnopqrstuvwxyz1_abcdefghijklmnopqrstuvwxyz2_abcdefghijklmnopqrstuvwxyz3_abcdefghijklmnopqrstuvwxyz4_abcdefghijklmnopqrstuvwxyz5_abcdefghijklmnopqrstuvwxyz6",
    outs = ["out"],
    cmd = "sleep 10 && echo foo > $OUT",
)

sh_cmd(
    name = "count",
    cmd = "printf 'foo'",
    expand_env_vars = False,
)
