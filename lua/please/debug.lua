local dap = require('dap')
local repl = require('dap.repl')
local future = require('please.future')
local logging = require('please.logging')
local utils = require('please.utils')
local query = require('please.query')
local plz = require('please.plz')

local M = {}

local get_free_port = function()
  local tcp = vim.loop.new_tcp()
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

M.setup = function()
  logging.debug('setting up plz debug adapter')

  ---@type fun(callback: fun(adapter: Adapter), config: DapConfiguration)
  dap.adapters.plz = function(callback, config)
    logging.log_call('plz dap adapter')

    local port = get_free_port()

    local cmd =
      { plz, '--repo_root', config.root, 'debug', '--port', port, config.label, unpack(config.extra_args or {}) }

    local stdout = function(err, data)
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
    local stderr = function(err, data)
      if err then
        logging.warn('error reading stderr from plz debug: %s', err)
      end
      if data then
        local stripped_line = utils.strip_plz_log_prefix(data:gsub('%s+$', ''))
        table.insert(stderr_lines, stripped_line)
        vim.schedule(function()
          repl.append(data)
        end)
      end
    end

    local on_exit = function(obj)
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

local target_debug_directory = function(root, label)
  local pkg = label:match('//(.+):.+')
  return future.vim.fs.joinpath(root, 'plz-out/debug', pkg)
end

local launch_delve = function(root, label)
  logging.log_call('launch_delve')

  local substitutePath = {
    {
      from = future.vim.fs.joinpath(target_debug_directory(root, label), 'third_party'),
      to = 'third_party',
    },
  }

  -- We would like a subtitutePath entry like { from = root, to = '' } which strips the repo root from paths but Delve
  -- doesn't allow either from or to to be empty. Instead, we add an entry for each child of the root.
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
  local children = vim.fn.systemlist('ls ' .. root)
  for _, path in ipairs(children) do
    table.insert(substitutePath, {
      from = future.vim.fs.joinpath(root, path),
      to = path,
    })
  end

  dap.run({
    type = 'plz',
    name = 'Launch plz debug with Delve',
    request = 'attach',
    mode = 'remote',
    substitutePath = substitutePath,
    root = root,
    label = label,
  })
end

local launch_debugpy = function(root, label)
  logging.log_call('launch_debugpy')

  local relative_sandbox_location = '.cache/pex/pex-debug'
  local local_explode_location = future.vim.fs.joinpath(target_debug_directory(root, label), relative_sandbox_location)
  local sandbox_explode_location = future.vim.fs.joinpath('/tmp/plz_sandbox', relative_sandbox_location)

  local pathMappings

  local is_target_sandboxed = function()
    local target_sandboxed, err = query.is_target_sandboxed(root, label)
    assert(not err, err)
    return target_sandboxed
  end

  if (vim.loop.os_uname().sysname == 'Linux') and is_target_sandboxed() then
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

  dap.run({
    type = 'plz',
    name = 'Launch plz debug with debugpy',
    request = 'attach',
    mode = 'remote',
    pathMappings = pathMappings,
    justMyCode = false,
    root = root,
    label = label,
    extra_args = { '-o=python.debugger:debugpy' },
  })
end

M.launchers = {
  go = launch_delve,
  python = launch_debugpy,
}

return M
