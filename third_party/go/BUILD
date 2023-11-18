go_toolchain(
    name = "toolchain",
    version = "1.18.2",
)

go_module(
    name = "dlv",
    binary = True,
    install = ["cmd/dlv"],
    module = "github.com/go-delve/delve",
    version = "v1.8.2",
    visibility = ["PUBLIC"],
    deps = [
        ":arch",
        ":argv",
        ":cobra",
        ":dap",
        ":ebpf",
        ":isatty",
        ":liner",
        ":logrus",
        ":lru",
        ":starlark",
        ":trie",
        ":yaml_v2",
    ],
)

go_module(
    name = "ebpf",
    install = [
        ".",
        "asm",
        "internal",
        "internal/btf",
        "internal/unix",
        "link",
        "ringbuf",
    ],
    module = "github.com/cilium/ebpf",
    version = "v0.7.0",
    deps = [":sys"],
)

go_module(
    name = "argv",
    module = "github.com/cosiner/argv",
    version = "v0.1.0",
)

go_module(
    name = "trie",
    module = "github.com/derekparker/trie",
    version = "v0.0.0-20200317170641-1fdf38b7b0e9",
)

go_module(
    name = "liner",
    module = "github.com/go-delve/liner",
    version = "v1.2.3-0.20220127212407-d32d89dd2a5d",
    deps = [":runewidth"],
)

go_module(
    name = "runewidth",
    module = "github.com/mattn/go-runewidth",
    version = "v0.0.3",
)

go_module(
    name = "dap",
    module = "github.com/google/go-dap",
    version = "v0.6.0",
)

go_module(
    name = "lru",
    install = ["simplelru"],
    module = "github.com/hashicorp/golang-lru",
    version = "v0.5.4",
)

go_module(
    name = "isatty",
    module = "github.com/mattn/go-isatty",
    version = "v0.0.3",
)

go_module(
    name = "logrus",
    module = "github.com/sirupsen/logrus",
    version = "v1.6.0",
    deps = [":sys"],
)

go_module(
    name = "cobra",
    install = [
        ".",
        "doc",
    ],
    module = "github.com/spf13/cobra",
    version = "v1.1.3",
    deps = [
        ":md2man",
        ":pflag",
        ":yaml_v2",
    ],
)

go_module(
    name = "md2man",
    install = ["md2man"],
    module = "github.com/cpuguy83/go-md2man/v2",
    version = "v2.0.2",
    deps = [":blackfriday"],
)

go_module(
    name = "blackfriday",
    module = "github.com/russross/blackfriday/v2",
    version = "v2.1.0",
)

go_module(
    name = "pflag",
    module = "github.com/spf13/pflag",
    version = "v1.0.5",
)

go_module(
    name = "starlark",
    install = [
        "resolve",
        "starlark",
        "syntax",
        "internal/compile",
        "internal/spell",
    ],
    module = "go.starlark.net",
    version = "v0.0.0-20200821142938-949cc6f4b097",
)

go_module(
    name = "arch",
    install = [
        "x86/x86asm",
        "arm64/arm64asm",
    ],
    module = "golang.org/x/arch",
    version = "v0.0.0-20190927153633-4e8777c89be4",
    deps = [":pdf"],
)

go_module(
    name = "pdf",
    module = "rsc.io/pdf",
    version = "v0.1.1",
)

go_module(
    name = "sys",
    install = [
        "unix",
        "internal/unsafeheader",
    ],
    module = "golang.org/x/sys",
    version = "v0.0.0-20211117180635-dee7805ff2e1",
)

go_module(
    name = "yaml_v2",
    module = "gopkg.in/yaml.v2",
    version = "v2.4.0",
)

go_module(
    name = "exp",
    install = [
        "constraints",
        "slices",
    ],
    module = "golang.org/x/exp",
    version = "v0.0.0-20220722155223-a9213eeb770e",
    visibility = ["PUBLIC"],
)

go_module(
    name = "testify",
    install = [
        "assert",
        "require",
        "suite",
    ],
    module = "github.com/stretchr/testify",
    version = "v1.8.1",
    visibility = ["PUBLIC"],
    deps = [
        ":difflib",
        ":objx",
        ":spew",
        ":yaml_v3",
    ],
)

go_module(
    name = "spew",
    install = [
        "spew",
    ],
    module = "github.com/davecgh/go-spew",
    version = "v1.1.1",
)

go_module(
    name = "difflib",
    install = [
        "difflib",
    ],
    module = "github.com/pmezard/go-difflib",
    version = "v1.0.0",
)

go_module(
    name = "objx",
    module = "github.com/stretchr/objx",
    version = "v0.5.0",
)

go_module(
    name = "yaml_v3",
    module = "gopkg.in/yaml.v3",
    version = "v3.0.1",
)
