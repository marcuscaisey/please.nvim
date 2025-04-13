def lua_toolchain(name:str, version:str, hash:str):
    """
    Downloads and compiles Lua and exposes the lua binary as the entry point :<name>|lua.

    Args:
        name: Name of the target.
        version: The version of Lua to download.
        hash: A hash for the downloaded archive.
        visibility: Visibility specification. Defaults to public.
    """
    platforms_by_os = {
        "linux": "linux",
        "darwin": "macosx",
    }
    if CONFIG.HOSTOS not in platforms_by_os:
        fail(f'lua_toolchain rule is not supported on OS: "{CONFIG.HOSTOS}"')
    platform = platforms_by_os[CONFIG.HOSTOS]

    download = remote_file(
        name = tag(name, "download"),
        hashes = [hash],
        url = f"https://www.lua.org/ftp/lua-{version}.tar.gz",
    )

    return genrule(
        name = name,
        srcs = {
            "download": download,
            "patch": "remove_readline_from_lua.patch",
        },
        outs = [name],
        binary = True,
        building_description = "Installing...",
        cmd = [
            "tar -xzvf $SRCS_DOWNLOAD",
            f"cd lua-{version}",
            "patch -p1 <$TMP_DIR/$SRCS_PATCH",
            f"make {platform}",
            "make INSTALL_TOP=$OUT install",
        ],
        entry_points = {
            "lua": f"{name}/bin/lua",
        },
    )

lua_toolchain(
    name = "_toolchain",
    hash = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333",
    version = "5.1.5",
)

def luarocks(name:str, version:str):
    """
    Downloads LuaRocks.

    Args:
        name: Name of the target.
        version: The version of LuaRocks to download.
        visibility: Visibility specification. Defaults to public.
    """
    download = remote_file(
        name = tag(name, "download"),
        url = f"https://github.com/luarocks/luarocks/archive/refs/tags/v{version}.tar.gz",
    )

    return genrule(
        name = name,
        srcs = [download],
        outs = [name],
        binary = True,
        building_description = "Installing...",
        cmd = [
            "tar -xzvf $SRCS",
            f"cd luarocks-{version}",
            f"./configure --prefix=$OUT --with-lua-bin=$(dirname $TOOLS_LUA)",
            "make",
            "make install",
            """sed -i'' -e '1a\\\npackage.path = arg[0]:gsub("bin/luarocks$", string.format("share/lua/%s/?.lua;", _VERSION:match("%d+%.%d+"))) .. package.path\n' $OUT/bin/luarocks""",
        ],
        entry_points = {
            "luarocks": f"{name}/bin/luarocks",
        },
        tools = {
            "lua": ":_toolchain|lua",
        },
    )

luarocks(
    name = "_luarocks",
    version = "3.11.1",
)

def luarocks_package(name:str, package:str=None, version:str, deps:list=[], visibility:list=["PUBLIC"]):
    """
    Downloads a LuaRocks package.

    Args:
        name: Name of the build target.
        package: Name of the package. Defaults to name.
        version: Version to download.
        deps: Dependencies of the package. These should be luarocks_package targets. Optional.
        visibility: Visibility specification. Defaults to public.
    """
    package = package or name
    return genrule(
        name = name,
        cmd = [
            f"$TOOL --tree=tree install --deps-mode=none {package} {version}",
            "mkdir _out",
            "if [ -d tree/share/lua ]; then cp -R $(find tree/share/lua -mindepth 2 -maxdepth 2) _out; fi",
            "if [ -d tree/lib/lua ]; then cp -R $(find tree/lib/lua -mindepth 2 -maxdepth 2) _out; fi",
        ],
        exported_deps = deps,
        output_dirs = ["_out"],
        sandbox = False,
        tools = [":_luarocks|luarocks"],
        visibility = visibility,
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
