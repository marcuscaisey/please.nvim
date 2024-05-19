local dap = require('dap')
local repl = require('dap.repl')
local future = require('please.future')
local logging = require('please.logging')
local query = require('please.query')
local plz = require('please.plz')

local M = {
  ---@type table<string, fun(root: string, label: string, test_selector: string?): boolean, string?>
  launchers = {},
}

local function get_free_port()
  local tcp = future.vim.uv.new_tcp()
  -- binding to port 0 lets the OS assign an ephemeral port which we can lookup with getsocketname
  tcp:bind('127.0.0.1', 0)
  local port = tcp:getsockname().port
  tcp:shutdown()
  tcp:close()
  return port
end

---Wrapper around Configuration which adds our custom fields.
---@class DapConfiguration : Configuration
---@field root string The root of the plz repo.
---@field label string The label of the target to debug.
---@field extra_args string[]? Any extra arguments to pass to plz debug.

function M.setup()
  logging.debug('setting up plz debug adapter')

  ---@type fun(callback: fun(adapter: Adapter), config: DapConfiguration)
  dap.adapters.plz = function(callback, config)
    logging.log_call('plz dap adapter')

    local port = get_free_port()

    local cmd =
      { plz, '--repo_root', config.root, 'debug', '--port', port, config.label, unpack(config.extra_args or {}) }

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

    future.vim.system(cmd, { stdout = stdout, stderr = stderr }, on_exit)

    callback({
      type = 'server',
      port = port,
      options = {
        max_retries = 50, -- plz debug sometimes takes a while to spin up
      },
    })
  end

  -- TODO: remove after upgrading debugpy version used by plz to >= 1.5.1 which sets only uncaught by default (currently
  -- debugpy also sets userUnhandled as well which is super annoying to use)
  dap.defaults.plz.exception_breakpoints = { 'uncaught' }
end

---@param root string
---@return string? goroot
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

---@param root string
---@param label string
---@param test_selector string?
---@return boolean success
---@return string? errmsg
M.launchers.go = function(root, label, test_selector)
  logging.log_call('launch_delve')

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
      from = future.vim.fs.joinpath(root, 'plz-out/go/src'),
      to = future.vim.fs.joinpath('pkg', arch),
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
        from = future.vim.fs.joinpath(root, path),
        to = path,
      })
    end
  end

  --- This needs to be the last entry since the empty 'to' will match all paths when mapping back from a path in the
  --- binary.
  table.insert(substitutePath, {
    from = future.vim.fs.joinpath(goroot, 'src'),
    to = '',
  })

  local extra_args = {}
  if test_selector then
    table.insert(extra_args, test_selector)
  end
  dap.run({
    type = 'plz',
    name = 'Launch plz debug with Delve',
    request = 'attach',
    mode = 'remote',
    substitutePath = substitutePath,
    root = root,
    label = label,
    extra_args = extra_args,
  })

  return true
end

local function target_debug_directory(root, label)
  local pkg = label:match('//(.+):.+')
  return future.vim.fs.joinpath(root, 'plz-out/debug', pkg)
end

---@param root string
---@param label string
---@param test_selector string?
---@return boolean success
---@return string? errmsg
M.launchers.python = function(root, label, test_selector)
  logging.log_call('launch_debugpy')

  local relative_sandbox_location = '.cache/pex/pex-debug'
  local local_explode_location = future.vim.fs.joinpath(target_debug_directory(root, label), relative_sandbox_location)
  local sandbox_explode_location = future.vim.fs.joinpath('/tmp/plz_sandbox', relative_sandbox_location)

  local pathMappings

  local function is_target_sandboxed()
    local target_sandboxed, err = query.is_target_sandboxed(root, label)
    assert(not err, err)
    return target_sandboxed
  end

  if (future.vim.uv.os_uname().sysname == 'Linux') and is_target_sandboxed() then
    pathMappings = {
      {
        localRoot = future.vim.fs.joinpath(local_explode_location, '.bootstrap'),
        remoteRoot = future.vim.fs.joinpath(sandbox_explode_location, '.bootstrap'),
      },
      {
        localRoot = future.vim.fs.joinpath(local_explode_location, 'third_party'),
        remoteRoot = future.vim.fs.joinpath(sandbox_explode_location, 'third_party'),
      },
      {
        localRoot = root,
        remoteRoot = sandbox_explode_location,
      },
    }
  else
    pathMappings = {
      {
        localRoot = future.vim.fs.joinpath(local_explode_location, '.bootstrap'),
        remoteRoot = future.vim.fs.joinpath(local_explode_location, '.bootstrap'),
      },
      {
        localRoot = future.vim.fs.joinpath(local_explode_location, 'third_party'),
        remoteRoot = future.vim.fs.joinpath(local_explode_location, 'third_party'),
      },
      {
        localRoot = root,
        remoteRoot = local_explode_location,
      },
    }
  end

  local extra_args = { '-o=python.debugger:debugpy' }
  if test_selector then
    table.insert(extra_args, test_selector)
  end
  dap.run({
    type = 'plz',
    name = 'Launch plz debug with debugpy',
    request = 'attach',
    mode = 'remote',
    pathMappings = pathMappings,
    justMyCode = false,
    root = root,
    label = label,
    extra_args = extra_args,
  })

  return true
end

return M
