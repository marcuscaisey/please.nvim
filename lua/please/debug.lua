local Path = require 'plenary.path'
local Job = require 'plenary.job'
local dap = require 'dap'
local repl = require 'dap.repl'
local logging = require 'please.logging'
local utils = require 'please.utils'

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
  logging.debug 'setting up plz debug adapter'

  dap.adapters.plz = function(callback, config)
    logging.debug('plz dap adapter called with callback=%s, config=%s', callback, vim.inspect(config))

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

    local job = Job:new {
      command = command,
      args = args,
      on_stdout = on_stdout,
      on_stderr = on_stderr,
      on_exit = on_exit,
    }
    job:start()

    -- FIXME: wait for a bit before connecting to the server. nvim-dap retries a couple of times but this usually isn't
    -- enough. would be nice if there was a way to make this configurable (number of retries and wait interval between them)
    vim.defer_fn(function()
      vim.schedule(function()
        callback { type = 'server', port = port }
      end)
    end, 500)
  end
end

local launch_delve = function(root, label)
  logging.debug('launch_delve called with root=%s, label=%s', root, label)

  local pkg = label:match '//(.+):.+'
  local substitutePath = {
    {
      from = Path:new(root, 'plz-out/debug', pkg, 'third_party').filename,
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
      from = Path:new(root, path).filename,
      to = path,
    })
  end

  dap.run {
    type = 'plz',
    name = 'Launch plz debug with Delve',
    request = 'attach',
    mode = 'remote',
    substitutePath = substitutePath,
    root = root,
    label = label,
  }
end

local launch_debugpy = function(root, label)
  local pkg = label:match '//(.+):.+'
  local substitutePath = {
    {
      from = table.concat({ root, 'plz-out/debug', pkg, 'third_party' }, '/'),
      to = 'third_party',
    },
  }
  local root_paths = vim.fn.systemlist('ls ' .. root)
  for _, path in ipairs(root_paths) do
    table.insert(substitutePath, {
      from = root .. '/' .. path,
      to = path,
    })
  end
  dap.run {
    type = 'plz',
    name = 'Launch plz debug with debugpy',
    request = 'attach',
    mode = 'remote',
    -- TODO: copy what should go in here from please-vscode
    -- substitutePath = substitutePath,
    root = root,
    label = label,
    extra_args = { '-o=python.debugger:debugpy' },
  }
end

M.launchers = {
  go = launch_delve,
  python = launch_debugpy,
}

return M
