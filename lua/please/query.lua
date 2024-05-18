local future = require('please.future')
local logging = require('please.logging')
local plz = require('please.plz')

local query = {}

---@param root string
---@param args string[]
---@return string?
---@return string?
local function plz_query(root, args)
  local res = future.vim.system({ plz, '--repo_root', root, 'query', unpack(args) }):wait()
  if res.code ~= 0 then
    return nil, vim.trim(res.stderr)
  end
  return vim.trim(res.stdout), nil
end

---Wrapper around plz query whatinputs which returns the labels of the build targets which a file is an input for.
---@param root string: absolute path to repo root
---@param filepath string: absolute path to file
---@return string[]?: build target labels
---@return string?: error if any
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
---@return string?: value of the field
---@return string?: error
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
---@return string?: error if any, this should be checked before using the result
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
---@return string[]?: value of the option
---@return string?: error if any, this should be checked before using the result
function query.config(root, option)
  logging.log_call('query.config')

  local output, err = plz_query(root, { 'config', option })
  if not output then
    return nil, string.format('plz query config %s: %s', option, err)
  end

  return vim.split(output, '\n')
end

return query
