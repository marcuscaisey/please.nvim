local logging = require('please.logging')
local plz = require('please.plz')
local runner = require('please.runner')

local M = {}

---@param root string
---@param args string[]
---@return string?
---@return string?
local function plz_query(root, args)
  local res = vim.system({ plz, '--repo_root', root, 'query', unpack(args) }):wait()
  if res.code ~= 0 then
    local stderr = vim.trim(res.stderr)
    if not stderr:match('\n') then
      -- If there's only one line, then strip off the prefix since the line is probably an error message. Otherwise, don't
      -- strip the lines since the prefixes (log level and time) might be useful for debugging.
      stderr = stderr:gsub('^%d+:%d+:%d+%.%d+ %u+: ', '')
      stderr = stderr:gsub('^Error: ', '')
    end
    return nil, stderr
  end
  return vim.trim(res.stdout), nil
end

---Wrapper around plz query whatinputs which returns the labels of the build targets which a file is an input for.
---@param root string: absolute path to repo root
---@param filepath string: absolute path to file
---@return string[]?
---@return string? errmsg
function M.whatinputs(root, filepath)
  logging.log_call('query.whatinputs')

  local output, err = plz_query(root, { 'whatinputs', filepath })
  if not output then
    return nil, string.format('plz query whatinputs %s: %s', filepath, err)
  end

  local labels = vim.split(output, '\n')
  for i, label in ipairs(labels) do
    local pkg, name = label:match('^//([^:]*):([^/]+)$')
    if pkg and name and name == vim.fs.basename(pkg) then
      labels[i] = label:gsub(':' .. name, '')
    end
  end

  return labels, nil
end

---Wrapper around plz query print which returns the value of the given field for the given build target.
---@param root string: absolute path to the repo root
---@param label string: a build label
---@param field string: field name
---@return string?
---@return string? errmsg
function M.print_field(root, label, field)
  logging.log_call('query.print')

  local output, err = plz_query(root, { 'print', label, '--field', field })
  if not output then
    return nil, string.format('plz query print %s --field %s: %s', label, field, err)
  end

  return output
end

---Returns whether the given build target should be run in a sandbox.
---@param root string: absolute path to the repo root
---@param label string: a build label
---@return boolean?
---@return string? errmsg
function M.is_target_sandboxed(root, label)
  logging.log_call('query.is_target_sandboxed')

  local test_value, err = M.print_field(root, label, 'test')
  if not test_value then
    return nil, string.format('determining if %s is sandboxed: %s', label, err)
  end

  local target_is_test = test_value == 'True'
  local sandbox_field = target_is_test and 'test_sandbox' or 'sandbox'

  local sandbox_value, err = M.print_field(root, label, sandbox_field)
  if not sandbox_value then
    return nil, string.format('determining if %s is sandboxed: %s', label, err)
  end

  return sandbox_value == 'True'
end

---Wrapper around plz query config which returns the value of the given option.
---@param root string: absolute path to the repo root
---@param option string: option name
---@return string[]?
---@return string? errmsg
function M.config(root, option)
  logging.log_call('query.config')

  local output, err = plz_query(root, { 'config', option })
  if not output then
    return nil, string.format('plz query config %s: %s', option, err)
  end

  return vim.split(output, '\n')
end

---Wrapper around plz query output which returns the output of the given build target.
---@param root string: absolute path to the repo root
---@param target string: build target label
---@return string?
---@return string? errmsg
function M.output(root, target)
  logging.log_call('query.output')

  local output, err = plz_query(root, { 'output', target })
  if err then
    return nil, string.format('plz query output %s: %s', target, err)
  end

  return output
end

---Determines the appropriate GOROOT for a repo and passes it to the given callback.
---The result is passed to a callback because a target may need to be built to create the GOROOT. Progress will be shown
---in a floating window in this case.
---Determining the GOROOT may fail. In this case, the callback will be passed `nil`, `errmsg`.
---@param root string absolute path to the repo root
---@param cb fun(goroot:string?, errmsg:string?) function called on success or error
function M.with_goroot(root, cb)
  logging.log_call('query.go_root')

  local gotool = 'go'
  local gotools, err = M.config(root, 'plugin.go.gotool')
  if gotools then
    gotool = gotools[1]
  elseif not (err or ''):match('Settable field not defined') then
    cb(nil, string.format('determining GOROOT: %s', err))
    return
  end

  if vim.startswith(gotool, ':') or vim.startswith(gotool, '//') then
    gotool = gotool:gsub('|go$', '')
    local gotool_output, err = M.output(root, gotool)
    if not gotool_output then
      cb(nil, string.format('determining GOROOT: %s', gotool, err))
      return
    end
    local rel_goroot = vim.trim(gotool_output)
    local goroot = vim.fs.joinpath(root, rel_goroot)
    if not vim.uv.fs_stat(goroot) then
      local msg = logging.format(
        'GOROOT "%s" for repository "%s" does not exist. Build plugin.go.gotool target "%s" to create it?',
        rel_goroot,
        root,
        gotool
      )
      local ok, result = pcall(vim.fn.confirm, msg, '&Yes\n&No', 1, 'Question')
      if not ok and result ~= 'Keyboard interrupt' then
        error(result)
      end
      local build = ok and result == 1
      if not build then
        cb(nil, string.format('determining GOROOT: GOROOT "%s" for repository "%s" does not exist', rel_goroot, root))
        return
      end
      runner.Runner.start(root, { 'build', gotool }, {
        on_exit = function(success, runner)
          if success then
            runner:minimise()
            logging.info('built plugin.go.gotool target "%s" successfully', gotool)
            cb(goroot)
          else
            cb(nil, string.format('determining GOROOT: building plugin.go.gotool target "%s" failed', gotool))
          end
        end,
      })
      return
    end
    cb(goroot)
    return
  end

  if vim.startswith(gotool, '/') then
    if not vim.uv.fs_stat(gotool) then
      cb(nil, string.format('determining GOROOT: plugin.go.gotool "%s" does not exist', gotool))
      return
    end
    local goroot_res = vim.system({ gotool, 'env', 'GOROOT' }):wait()
    if goroot_res.code == 0 then
      cb(vim.trim(goroot_res.stdout))
      return
    else
      cb(nil, string.format('determining GOROOT: %s env GOROOT: %s', gotool, goroot_res.stderr))
      return
    end
  end

  local build_paths, err = M.config(root, 'build.path')
  if not build_paths then
    cb(nil, string.format('determining GOROOT: %s', err))
    return
  end
  for _, build_path in ipairs(build_paths) do
    for path in vim.gsplit(build_path, ':') do
      local go = vim.fs.joinpath(path, gotool)
      if vim.uv.fs_stat(go) then
        local goroot_res = vim.system({ go, 'env', 'GOROOT' }):wait()
        if goroot_res.code == 0 then
          cb(vim.trim(goroot_res.stdout))
          return
        else
          cb(nil, string.format('determining GOROOT: %s env GOROOT: %s', go, goroot_res.stderr))
          return
        end
      end
    end
  end

  cb(
    nil,
    string.format(
      'determining GOROOT: plugin.go.gotool "%s" not found in build.path "%s"',
      gotool,
      table.concat(build_paths, ':')
    )
  )
end

return M
