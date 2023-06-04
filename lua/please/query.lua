local Path = require('plenary.path')
local Job = require('plenary.job')
local logging = require('please.logging')
local utils = require('please.utils')
local plz = require('please.plz')

local query = {}

local strip_and_join_stderr = function(lines)
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
local exec_plz = function(args, cwd)
  local job_opts = {
    command = plz,
    args = args,
  }
  if cwd then
    job_opts.cwd = cwd
  end
  local job = Job:new(job_opts)
  local stdout_lines, code = job:sync()

  if code ~= 0 then
    return stdout_lines, strip_and_join_stderr(job:stderr_result())
  end

  return stdout_lines, nil
end

---@param path string: an absolute path
---@return string?: an absolute path
---@return string?: error if any, this should be checked before using the repo root
query.reporoot = function(path)
  logging.log_call('query.reporoot')

  local path_obj = Path:new(path)

  if not path_obj:is_dir() then
    path_obj = path_obj:parent()
  end

  local cwd = path_obj.filename
  local output, err = exec_plz({ 'query', 'reporoot' }, cwd)
  if err then
    return nil, err
  end

  local root = vim.fn.resolve(output[1])
  -- If root is not a parent of path, then it must have come from the global plzconfig which has a defaultrepo set. We
  -- shouldn't return it in this case since it won't be of any use for doing stuff with the current path.
  if vim.fn.resolve(path):sub(1, #root) ~= root then
    return nil, "Couldn't locate the repo root. Are you sure you're inside a plz repo?"
  end
  return root
end

---Wrapper around plz query whatinputs which returns the labels of the build targets which filepath is an input for.
---@param root string: an absolute path to the repo root
---@param filepath string: an absolute path or path relative to the repo root
---@return string[]?: build target labels
---@return string|nil: error if any, this should be checked before using the labels
query.whatinputs = function(root, filepath)
  logging.log_call('query.whatinputs')

  filepath = Path:new(filepath):make_relative(root)

  local output, err = exec_plz({ 'query', 'whatinputs', '--repo_root', root, filepath })
  if err then
    return nil, err
  end

  -- whatinputs can exit with no error even if it errors so check the first line looks like a build label
  if not output[1]:match('^//') then
    return nil, strip_and_join_stderr(output)
  end

  return output, nil
end

local target_value = function(root, label, field)
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
query.is_target_sandboxed = function(root, label)
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
