local future = require('please.future')
local logging = require('please.logging')
local utils = require('please.utils')
local plz = require('please.plz')

local query = {}

local function strip_and_join_stderr(lines)
  -- If there's only one line, then strip off the prefix since the line is probably an error message. Otherwise, don't
  -- strip the lines since the prefixes (log level and time) might be useful for debugging.
  if #lines == 1 then
    return utils.strip_plz_log_prefix(lines[1])
  end
  return table.concat(lines, '\n')
end

---@param args string[]
---@param cwd string?
---@return string[]: stdout lines
---@return string|nil: error if any
local function exec_plz(args, cwd)
  local result = future.vim.system({ plz, unpack(args) }, { cwd = cwd }):wait()

  local stdout_lines = vim.split(result.stdout, '\n', { trimempty = true })
  if result.code ~= 0 then
    local stderr_lines = vim.split(result.stderr, '\n', { trimempty = true })
    return stdout_lines, strip_and_join_stderr(stderr_lines)
  end

  return stdout_lines, nil
end

---Wrapper around plz query whatinputs which returns the labels of the build targets which filepath is an input for.
---@param root string: an absolute path to the repo root
---@param filepath string: an absolute path or path relative to the repo root
---@return string[]?: build target labels
---@return string|nil: error if any, this should be checked before using the labels
function query.whatinputs(root, filepath)
  logging.log_call('query.whatinputs')

  local normalized_root = vim.fs.normalize(root)
  local normalized_filepath = vim.fs.normalize(filepath)
  local relative_filepath = normalized_filepath:gsub('^' .. vim.pesc(normalized_root) .. '/', '')

  local output, err = exec_plz({ 'query', 'whatinputs', '--repo_root', root, relative_filepath })
  if err then
    return nil, err
  end

  -- whatinputs can exit with no error even if it errors so check the first line looks like a build label
  if not output[1]:match('^//') then
    return nil, strip_and_join_stderr(output)
  end

  return output, nil
end

local function target_value(root, label, field)
  local output, err = exec_plz({ '--repo_root', root, 'query', 'print', label, '--field', field })
  if err then
    return nil, err
  end
  return output[1]
end

---Returns whether the given build target should be run in a sandbox.
---@param root string: absolute path to the repo root
---@param label string: a build label
---@return boolean?
---@return string?: error if any, this should be checked before using the result
function query.is_target_sandboxed(root, label)
  logging.log_call('query.is_target_sandboxed')

  local test_value, err = target_value(root, label, 'test')
  if err then
    return nil, err
  end

  local target_is_test = test_value == 'True'

  local sandbox_field
  if target_is_test then
    sandbox_field = 'test_sandbox'
  else
    sandbox_field = 'sandbox'
  end

  local output, plz_err = exec_plz({ '--repo_root', root, 'query', 'print', label, '--field', sandbox_field })
  if plz_err then
    return nil, plz_err
  end

  return output[1] == 'True'
end

return query
