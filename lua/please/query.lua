local Path = require 'plenary.path'
local Job = require 'plenary.job'

local query = {}

---Wrapper around plz query reporoot which returns the root of the repo that the given path is in.
---@param path string: an absolute path
---@return string: an absolute path
---@return string|nil: error if any, this should be checked before using the repo root
query.reporoot = function(path)
  local path_obj = Path:new(path)

  if not path_obj:is_absolute() then
    error(string.format('path must be absolute, got %s', path))
  end

  if not path_obj:is_dir() then
    path_obj = path_obj:parent()
  end

  local job = Job:new {
    command = 'plz',
    args = { 'query', 'reporoot' },
    cwd = path_obj.filename,
  }
  local stdout, code = job:sync()
  if code ~= 0 then
    return nil, table.concat(job:stderr_result(), '\n')
  end

  local root = vim.fn.resolve(stdout[1])
  -- If root is not a parent of path, then it must have come from the global plzconfig. We shouldn't return it in this
  -- case since it won't be of any use for doing stuff with the current path.
  if vim.fn.resolve(path):sub(1, #root) ~= root then
    return nil, "Couldn't locate the repo root. Are you sure you're inside a plz repo?"
  end
  return root
end

---Wrapper around plz query whatinputs which returns the labels of the build targets which filepath is an input for.
---@param root string: an absolute path to the repo root
---@param filepath string: an absolute path or path relative to the repo root
---@return table: build target labels
---@return string|nil: error if any, this should be checked before using the labels
query.whatinputs = function(root, filepath)
  local root_obj = Path:new(root)
  local filepath_obj = Path:new(filepath)

  if not root_obj:is_absolute() then
    error(string.format('root must be absolute, got %s', root))
  end

  if
    (filepath_obj:is_absolute() and filepath_obj:is_dir())
    or (not filepath_obj:is_absolute() and root_obj:joinpath(filepath_obj):is_dir())
  then
    error(string.format('filepath must point to a file, got %s', filepath))
  end

  filepath = Path:new(filepath):make_relative(root)

  local job = Job:new {
    command = 'plz',
    args = { 'query', 'whatinputs', '--repo_root', root, filepath },
  }
  local stdout, code = job:sync()
  if code ~= 0 then
    return nil, table.concat(job:stderr_result(), '\n')
  end

  -- whatinputs can exit with a 0 even if it errors so check the first line looks like a build label
  if not stdout[1]:match '^//' then
    return nil, stdout[1]
  end

  return stdout, nil
end

return query
