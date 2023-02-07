local Path = require('plenary.path')
local Job = require('plenary.job')
local dap = require('dap')
local repl = require('dap.repl')
local logging = require('please.logging')
local utils = require('please.utils')
local query = require('please.query')

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

M.setup = function()
  logging.debug('setting up plz debug adapter')

  dap.adapters.plz = function(callback, config)
    logging.log_call('plz dap adapter')

    local port = get_free_port()

    local command = 'plz'
    local args = { '--repo_root', config.root, 'debug', '--port', port, config.label, unpack(config.extra_args or {}) }

    local on_stdout = function(err, chunk)
      if err then
        logging.warn('error reading stdout from plz debug: %s', err)
      end
      if chunk then
        vim.schedule(function()
          repl.append(chunk)
        end)
      end
    end

    local stderr_lines = {}
    local on_stderr = function(err, chunk)
      if err then
        logging.warn('error reading stderr from plz debug: %s', err)
      end
      if chunk then
        local stripped_line = utils.strip_plz_log_prefix(chunk:gsub('%s+$', ''))
        table.insert(stderr_lines, stripped_line)
        vim.schedule(function()
          repl.append(chunk)
        end)
      end
    end

    local on_exit = function(_, code)
      if code ~= 0 then
        logging.info('plz debug exited with code %d\n%s', code, table.concat(stderr_lines, '\n'))
      end
    end

    local job = Job:new({
      command = command,
      args = args,
      on_stdout = on_stdout,
      on_stderr = on_stderr,
      on_exit = on_exit,
    })
    job:start()

    local callback_opts = {
      type = 'server',
      port = port,
      options = {
        max_retries = 50, -- plz debug sometimes takes a while to spin up
      },
    }
    logging.debug('calling DAP adapter callback with opts: %s', vim.inspect(callback_opts))

    callback(callback_opts)
  end

  -- TODO: remove after upgrading debugpy version used by plz to >= 1.5.1 which sets only uncaught by default (currently
  -- debugpy also sets userUnhandled as well which is super annoying to use)
  dap.defaults.plz.exception_breakpoints = { 'uncaught' }
end

local join_paths = function(...)
  return Path:new(...).filename
end

local target_debug_directory = function(root, label)
  local pkg = label:match('//(.+):.+')
  return join_paths(root, 'plz-out/debug', pkg)
end

local launch_delve = function(root, label)
  logging.log_call('launch_delve')

  local substitutePath = {
    {
      from = join_paths(target_debug_directory(root, label), 'third_party'),
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
      from = join_paths(root, path),
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
  local local_explode_location = join_paths(target_debug_directory(root, label), relative_sandbox_location)
  local sandbox_explode_location = join_paths('/tmp/plz_sandbox', relative_sandbox_location)

  local pathMappings

  local is_target_sandboxed = function()
    local target_sandboxed, err = query.is_target_sandboxed(root, label)
    assert(not err, err)
    return target_sandboxed
  end

  if (vim.loop.os_uname().sysname == 'Linux') and is_target_sandboxed() then
    pathMappings = {
      {
        localRoot = join_paths(local_explode_location, '.bootstrap'),
        remoteRoot = join_paths(sandbox_explode_location, '.bootstrap'),
      },
      {
        localRoot = join_paths(local_explode_location, 'third_party'),
        remoteRoot = join_paths(sandbox_explode_location, 'third_party'),
      },
      {
        localRoot = root,
        remoteRoot = sandbox_explode_location,
      },
    }
  else
    pathMappings = {
      {
        localRoot = join_paths(local_explode_location, '.bootstrap'),
        remoteRoot = join_paths(local_explode_location, '.bootstrap'),
      },
      {
        localRoot = join_paths(local_explode_location, 'third_party'),
        remoteRoot = join_paths(local_explode_location, 'third_party'),
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
