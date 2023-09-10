genrule(
    name = "abcdefghijklmnopqrstuvwxyz1_abcdefghijklmnopqrstuvwxyz2_abcdefghijklmnopqrstuvwxyz3",
    outs = ["out"],
    cmd = "sleep 10 && echo foo > $OUT",
)

sh_cmd(
    name = "count",
    cmd = "for i in $(seq 1 100); do echo line $i && sleep 0.1; done",
    expand_env_vars = False,
)
