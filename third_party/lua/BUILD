subinclude("//build_defs:lua")

lua_toolchain(
    name = "toolchain",
    hash = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333",
    version = "5.1.5",
)

luarocks(
    name = "luarocks",
    version = "3.11.1",
)

luarocks_package(
    name = "busted",
    version = "2.2.0-1",
    deps = [
        ":dkjson",
        ":lua_cliargs",
        ":lua_term",
        ":luassert",
        ":luasystem",
        ":mediator_lua",
        ":penlight",
        ":say",
    ],
)

luarocks_package(
    name = "dkjson",
    version = "2.7-1",
)

luarocks_package(
    name = "lua_cliargs",
    version = "3.0.2-1",
)

luarocks_package(
    name = "lua_term",
    package = "lua-term",
    version = "0.8-1",
)

luarocks_package(
    name = "luassert",
    version = "1.9.0-1",
    deps = [
        ":say",
    ],
)

luarocks_package(
    name = "say",
    version = "1.4.1-3",
)

luarocks_package(
    name = "mediator_lua",
    version = "1.1.2-0",
)

luarocks_package(
    name = "luasystem",
    version = "0.3.0-2",
)

luarocks_package(
    name = "penlight",
    version = "1.14.0-2",
    deps = [
        ":luafilesystem",
    ],
)

luarocks_package(
    name = "luafilesystem",
    version = "1.8.0-1",
)
