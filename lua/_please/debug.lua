local logging = require('_please.logging')
local query = require('_please.query')
local plz = require('_please.plz')

local M = {
    ---@type table<string, fun(root: string, target: string, extra_args: string[]): boolean, string?>
    launchers = {},
}

local function free_port()
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

    logging.debug('Setting up plz debug adapter')

    local ok, dap = pcall(require, 'dap')
    if not ok then
        logging.error(
            'Failed to debug: nvim-dap is required for debugging but it is not installed. Install it from https://github.com/mfussenegger/nvim-dap.'
        )
        return
    end
    local repl = require('dap.repl')
    dap.adapters.plz = function(callback, config)
        logging.log_call('dap.adapters.plz')

        local port = free_port()

        local cmd =
            { plz, '--repo_root', config.root, 'debug', '--port', port, config.target, unpack(config.extra_args or {}) }

        local function stdout(err, data)
            if err then
                logging.warn('Error reading stdout from plz debug: %s', err)
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
                logging.warn('Error reading stderr from plz debug: %s', err)
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

        local ok, err = pcall(vim.system, cmd, { stdout = stdout, stderr = stderr }, on_exit)
        if not ok then
            logging.error('Failed to start debugger with %q: %s', table.concat(cmd, ' '), err)
            return
        end

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
    local dap_config = {
        type = 'plz',
        request = 'attach',
        name = 'Attach to plz debug',
    }
    dap_config = vim.tbl_deep_extend('error', dap_config, config)
    local dap = require('dap')
    dap.run(dap_config)
end

function M.launchers.go(root, target, extra_args)
    logging.log_call('debug.launchers.go')

    local arches, err = query.config(root, 'build.arch')
    if err then ---@cast arches -?
        return false, string.format('launching delve: resolving host arch: %s', err)
    end
    local arch = arches[1]
    local goroot, err = query.goroot(root)
    if err then ---@cast goroot -?
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
        if err then ---@cast target_sandboxed -?
            return false, string.format('launching debugpy: %s', err)
        end
        if target_sandboxed then
            remote_runtime_dir = '/tmp/plz_sandbox'
        end
    end

    local pex_explode_dir = '.cache/pex/pex-debug'
    local local_pex_explode_dir = vim.fs.joinpath(local_runtime_dir, pex_explode_dir)
    local remote_pex_explode_dir = vim.fs.joinpath(remote_runtime_dir, pex_explode_dir)
    local target_out, err = query.print_field(root, target, 'outs')
    if err then ---@cast target_out -?
        return false, string.format('launching debugpy: %s', err)
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
