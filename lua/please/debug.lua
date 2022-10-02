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

-- TODO: upstream this with configurable timeout and interval
-- patch dap.Session.connect so that it retries for a given amount of time and at a given interval
-- the existing implementation only retries twice with an interval of 500ms, this isn't enough time to spin up plz debug
-- and connect to whatever debugger it's running (especially debugpy which is a Python script)
local patch_dap_session_connect = function()
  logging.debug('patching nvim-dap Session.connect')

  local rpc = require('dap.rpc')
  local Session = require('dap.session')
  local log = require('dap.log').create_logger('dap.log')

  local timeout = 5000
  local retry_interval = 100

  local next_session_id = 1

  local function new_session(adapter, opts)
    local handlers = {}
    handlers.after = opts.after
    handlers.reverse_requests = {}
    local state = {
      id = next_session_id,
      handlers = handlers,
      message_callbacks = {},
      message_requests = {},
      initialized = false,
      seq = 0,
      stopped_thread_id = nil,
      current_frame = nil,
      threads = {},
      adapter = adapter,
      dirty = {},
      capabilities = {},
    }
    next_session_id = next_session_id + 1
    return setmetatable(state, { __index = Session })
  end

  function Session.connect(_, adapter, opts, on_connect)
    local session = new_session(adapter, opts or {})
    local closed = false
    local client = vim.loop.new_tcp()

    local function close()
      if closed then
        return
      end
      closed = true
      client:shutdown()
      client:close()
      session.threads = {}
      session.message_callbacks = {}
      session.message_requests = {}
    end

    session.client = {
      write = function(line)
        client:write(line)
      end,
      close = close,
    }

    log.debug(
      string.format('Connecting to debug adapter, retrying every %dms for %dms', retry_interval, timeout),
      adapter
    )

    local timed_out = false
    vim.defer_fn(function()
      timed_out = true
    end, timeout)

    local host = adapter.host or '127.0.0.1'
    local on_addresses
    on_addresses = function(err, addresses, retry_count)
      if err or #addresses == 0 then
        err = err or ('Could not resolve ' .. host)
        on_connect(err)
        return
      end
      local address = addresses[1]
      client:connect(address.addr, tonumber(adapter.port), function(conn_err)
        if conn_err then
          if timed_out then
            on_connect(conn_err)
          else
            retry_count = retry_count or 1
            log.debug(string.format('Connecting to debug adapter attempt %d failed', retry_count))
            -- Possible luv bug? A second client:connect gets stuck
            -- Create new handle as workaround
            client:close()
            client = vim.loop.new_tcp()
            local timer = vim.loop.new_timer()
            timer:start(retry_interval, 0, function()
              timer:stop()
              timer:close()
              on_addresses(nil, addresses, retry_count + 1)
            end)
          end
          return
        end
        log.debug('Connected to debug adapter')
        local handle_body = vim.schedule_wrap(function(body)
          session:handle_body(body)
        end)
        client:read_start(rpc.create_read_loop(handle_body, function()
          if not closed then
            closed = true
            client:shutdown()
            client:close()
          end
          local s = dap().session()
          if s == session then
            vim.schedule(function()
              utils.notify('Debug adapter disconnected', vim.log.levels.INFO)
            end)
            dap().set_session(nil)
          end
        end))
        on_connect(nil)
      end)
    end
    -- getaddrinfo fails for some users with `bad argument #3 to 'getaddrinfo' (Invalid protocol hint)`
    -- It should generally work with luv 1.42.0 but some still get errors
    if vim.loop.version() >= 76288 then
      local ok, err = pcall(vim.loop.getaddrinfo, host, nil, { protocol = 'tcp' }, on_addresses)
      if not ok then
        log.warn(err)
        on_addresses(nil, { { addr = host } })
      end
    else
      on_addresses(nil, { { addr = host } })
    end
    return session
  end
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

    callback({ type = 'server', port = port })
  end

  -- TODO: remove after upgrading debugpy version used by plz to >= 1.5.1 which sets only uncaught by default (currently
  -- debugpy also sets userUnhandled as well which is super annoying to use)
  dap.defaults.plz.exception_breakpoints = { 'uncaught' }

  patch_dap_session_connect()
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
