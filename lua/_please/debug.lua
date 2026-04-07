local function safe_require(module)
    return setmetatable({}, {
        __index = function(_, key)
            local ok, value = pcall(require, module)
            if not ok then
                error(
                    'nvim-dap is required to use please.debug but it is not installed. Install it from https://github.com/mfussenegger/nvim-dap.'
                )
            end
            return value[key]
        end,
    })
end

---@module 'dap'
local dap = safe_require('dap')
---@module 'dap.repl'
local repl = safe_require('dap.repl')
local logging = require('_please.logging')
local query = require('_please.query')
local plz = require('_please.plz')

local M = {
    ---@type table<string, fun(root: string, target: string, extra_args: string[]): boolean, string?>
    launchers = {},
}

local function get_free_port()
    local tcp = assert(vim.uv.new_tcp())
    -- binding to port 0 lets the OS assign an ephemeral port which we can lookup with getsocketname
    tcp:bind('127.0.0.1', 0)
    local port = tcp:getsockname().port
    tcp:shutdown()
    tcp:close()
    return port
end

local debug_adapter_setup = false

local function setup_debug_adapter()
    if debug_adapter_setup then
        return
    end

    logging.debug('setting up plz debug adapter')

    ---@type dap.AdapterFactory
    dap.adapters.plz = function(callback, config)
        logging.log_call('dap.adapters.plz')

        local port = get_free_port()

        local cmd =
            { plz, '--repo_root', config.root, 'debug', '--port', port, config.target, unpack(config.extra_args or {}) }

        local function stdout(err, data)
            if err then
                logging.warn('error reading stdout from plz debug: %s', err)
            end
            if data then
                vim.schedule(function()
                    repl.append(data)
                end)
            end
        end

        local stderr_lines = {}
        local function stderr(err, data)
            if err then
                logging.warn('error reading stderr from plz debug: %s', err)
            end
            if data then
                table.insert(stderr_lines, data)
                vim.schedule(function()
                    repl.append(data)
                end)
            end
        end

        local function on_exit(obj)
            if obj.code ~= 0 then
                logging.info('plz debug exited with code %d\n%s', obj.code, table.concat(stderr_lines, '\n'))
            end
        end

        vim.system(cmd, { stdout = stdout, stderr = stderr }, on_exit)

        callback({
            type = 'server',
            port = port,
            options = {
                max_retries = 50, -- plz debug sometimes takes a while to spin up
            },
        })
    end

    debug_adapter_setup = true
end

---@class _please.debug.AdapterConfig
---@field root string root of the plz repo
---@field target string target to debug
---@field extra_args string[] extra arguments to pass to plz debug
---@field [string] any any debug adapter specific config

---@param config _please.debug.AdapterConfig
local function launch_debug_adapter(config)
    setup_debug_adapter()
    config = vim.tbl_extend('error', config, {
        type = 'plz',
        name = 'Attach to plz debug',
        request = 'attach',
        mode = 'remote',
    })
    dap.run(config)
end

---@param root string
---@return string?
---@return string? errmsg
local function plz_goroot(root)
    local gotools, err = query.config(root, 'plugin.go.gotool')
    if not gotools then
        return nil, string.format('determining GOROOT: %s', err)
    end
    local gotool = gotools[1]

    if vim.startswith(gotool, ':') or vim.startswith(gotool, '//') then
        gotool = gotool:gsub('|go$', '')
        local gotool_output, err = query.output(root, gotool)
        if not gotool_output then
            return nil, string.format('determining GOROOT: querying output of plugin.go.gotool target: %s', gotool, err)
        end
        return vim.fs.joinpath(root, gotool_output)
    end

    if vim.startswith(gotool, '/') then
        if not vim.uv.fs_stat(gotool) then
            return nil, string.format('determining GOROOT: plugin.go.gotool %s does not exist', gotool)
        end
        local goroot_res = vim.system({ gotool, 'env', 'GOROOT' }):wait()
        if goroot_res.code == 0 then
            return vim.trim(goroot_res.stdout)
        else
            return nil, string.format('determining GOROOT: %s env GOROOT: %s', gotool, goroot_res.stderr)
        end
    end

    local build_paths, err = query.config(root, 'build.path')
    if not build_paths then
        return nil, string.format('determining GOROOT: querying value of build.path: %s', err)
    end
    for _, build_path in ipairs(build_paths) do
        for build_path_part in vim.gsplit(build_path, ':') do
            local go = vim.fs.joinpath(build_path_part, gotool)
            if vim.uv.fs_stat(go) then
                local goroot_res = vim.system({ go, 'env', 'GOROOT' }):wait()
                if goroot_res.code == 0 then
                    return vim.trim(goroot_res.stdout)
                else
                    return nil, string.format('determing GOROOT: %s env GOROOT: %s', go, goroot_res.stderr)
                end
            end
        end
    end

    return nil,
        string.format(
            'determining GOROOT: plugin.go.gotool %s not found in build.path %s',
            gotool,
            table.concat(build_paths, ':')
        )
end

function M.launchers.go(root, target, extra_args)
    logging.log_call('debug.launchers.go')

    local arches, err = query.config(root, 'build.arch')
    if not arches then
        return false, string.format('launching delve: determining host arch: %s', err)
    end
    local arch = arches[1]
    local goroot, err = plz_goroot(root)
    if not goroot then
        return false, string.format('launching delve: %s', err)
    end

    local substitutePath = {
        {
            from = vim.fs.joinpath(root, 'plz-out/go/src'),
            to = vim.fs.joinpath('pkg', arch),
        },
    }

    -- We would like to have the entry { from = root, to = '' } which makes paths under the repo relative but we also need
    -- the entry { from = joinpath(goroot, 'src'), to = '' } to make paths under the GOROOT relative as well. Delve needs
    -- to map paths back from the binary to the source so we can't have two entries with the same 'to'. Instead of
    -- { from = root, to = '' }, we add an entry for each child of the root.
    --
    -- Example: if we have a repo like the following
    --   root
    --   ├── foo
    --   │   ├── BUILD
    --   │   ├── foo.go
    --   │   └── foo_test.go
    --   └── bar.go
    -- then we'll add the following entries to substitutePath:
    --   - { from = 'root/foo', to = 'foo' }
    --   - { from = 'root/bar.go', to = 'bar.go' }
    for path in vim.fs.dir(root) do
        -- plz-out doesn't contain any source files
        if path ~= 'plz-out' then
            table.insert(substitutePath, {
                from = vim.fs.joinpath(root, path),
                to = path,
            })
        end
    end

    --- This needs to be the last entry since the empty 'to' will match all paths when mapping back from a path in the
    --- binary.
    table.insert(substitutePath, {
        from = vim.fs.joinpath(goroot, 'src'),
        to = '',
    })

    launch_debug_adapter({
        root = root,
        target = target,
        extra_args = extra_args,
        substitutePath = substitutePath,
    })

    return true
end

function M.launchers.python(root, target, extra_args)
    logging.log_call('debug.launcher.python')

    local target_pkg = target:match('^//([^:]+):?.*$')
    local local_runtime_dir = vim.fs.joinpath(root, 'plz-out/debug', target_pkg)
    local remote_runtime_dir = local_runtime_dir
    if vim.uv.os_uname().sysname == 'Linux' then
        local target_sandboxed, err = query.is_target_sandboxed(root, target)
        if target_sandboxed == nil then
            return false, ('launching debugpy: %s'):format(err)
        end
        if target_sandboxed then
            remote_runtime_dir = '/tmp/plz_sandbox'
        end
    end

    local pex_explode_dir = '.cache/pex/pex-debug'
    local local_pex_explode_dir = vim.fs.joinpath(local_runtime_dir, pex_explode_dir)
    local remote_pex_explode_dir = vim.fs.joinpath(remote_runtime_dir, pex_explode_dir)
    local target_out, err = query.print_field(root, target, 'outs')
    if not target_out then
        return false, ('launching debugpy: %s'):format(err)
    end

    local path_mappings = {
        {
            remoteRoot = vim.fs.joinpath(remote_pex_explode_dir, '.bootstrap'),
            localRoot = vim.fs.joinpath(local_pex_explode_dir, '.bootstrap'),
        },
        {
            remoteRoot = vim.fs.joinpath(remote_pex_explode_dir, 'third_party'),
            localRoot = vim.fs.joinpath(local_pex_explode_dir, 'third_party'),
        },
        {
            remoteRoot = remote_pex_explode_dir,
            localRoot = root,
        },
        {
            remoteRoot = vim.fs.joinpath(remote_runtime_dir, target_out, '__main__.py'),
            localRoot = vim.fs.joinpath(local_pex_explode_dir, '__main__.py'),
        },
    }

    extra_args = { '-o=plugin.python.debugger:debugpy', unpack(extra_args) }

    launch_debug_adapter({
        root = root,
        target = target,
        extra_args = extra_args,
        pathMappings = path_mappings,
        justMyCode = false,
    })

    return true
end

return M
