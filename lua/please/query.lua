local logging = require('please.logging')
local plz = require('please.plz')

local query = {}

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
function query.whatinputs(root, filepath)
  logging.log_call('query.whatinputs')

  local output, err = plz_query(root, { 'whatinputs', filepath })
  if not output then
    return nil, string.format('plz query whatinputs %s: %s', filepath, err)
  end

  return vim.split(output, '\n'), nil
end

---Wrapper around plz query print which returns the value of the given field for the given build target.
---@param root string: absolute path to the repo root
---@param label string: a build label
---@param field string: field name
---@return string?
---@return string? errmsg
function query.print_field(root, label, field)
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
function query.is_target_sandboxed(root, label)
  logging.log_call('query.is_target_sandboxed')

  local test_value, err = query.print_field(root, label, 'test')
  if not test_value then
    return nil, string.format('determining if %s is sandboxed: %s', label, err)
  end

  local target_is_test = test_value == 'True'
  local sandbox_field = target_is_test and 'test_sandbox' or 'sandbox'

  local sandbox_value, err = query.print_field(root, label, sandbox_field)
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
function query.config(root, option)
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
function query.output(root, target)
  logging.log_call('query.output')

  local output, err = plz_query(root, { 'output', target })
  if err then
    return nil, string.format('plz query output %s: %s', target, err)
  end

  return output
end

return query
