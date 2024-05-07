local M = {}

--- Concatenate directories and/or file paths into a single path with normalization
--- (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)
---
---@param ... string
---@return string
function M.joinpath(...)
  return (table.concat({ ... }, '/'):gsub('//+', '/'))
end

--- Find the first parent directory containing a specific "marker", relative to a buffer's
--- directory.
---
--- Example:
---
--- ```lua
--- -- Find the root of a Python project, starting from file 'main.py'
--- vim.fs.root(vim.fs.joinpath(vim.env.PWD, 'main.py'), {'pyproject.toml', 'setup.py' })
---
--- -- Find the root of a git repository
--- vim.fs.root(0, '.git')
---
--- -- Find the parent directory containing any file with a .csproj extension
--- vim.fs.root(0, function(name, path)
---   return name:match('%.csproj$') ~= nil
--- end)
--- ```
---
--- @param source integer|string Buffer number (0 for current buffer) or file path to begin the
---               search from.
--- @param marker (string|string[]|fun(name: string, path: string): boolean) A marker, or list
---               of markers, to search for. If a function, the function is called for each
---               evaluated item and should return true if {name} and {path} are a match.
--- @return string? # Directory path containing one of the given markers, or nil if no directory was
---         found.
function M.root(source, marker)
  assert(source, 'missing required argument: source')
  assert(marker, 'missing required argument: marker')

  local path ---@type string
  if type(source) == 'string' then
    path = source
  elseif type(source) == 'number' then
    path = vim.api.nvim_buf_get_name(source)
  else
    error('invalid type for argument "source": expected string or buffer number')
  end

  local paths = vim.fs.find(marker, {
    upward = true,
    path = path,
  })

  if #paths == 0 then
    return nil
  end

  return vim.fs.dirname(paths[1])
end

return M
