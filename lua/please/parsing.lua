local Path = require 'plenary.path'
local treesitter = require 'vim.treesitter'
local treesitter_query = require 'vim.treesitter.query'
local ts_utils = require 'nvim-treesitter.ts_utils'

local parsing = {}

-- selects calls which have a kwarg / value pair of the form `name = %s` where %s is the name of the target we are
-- looking for
local build_target_query = [[
(call
  function: (identifier)
  arguments: (argument_list
    (keyword_argument
      name: (
        (identifier) @kwarg
        (#eq? @kwarg "name"))
      value: (
        (string) @value
        (#eq? @value "\"%s\""))))) @call
]]

-- TODO: should we get these from the .plzconfig? feels like it should be really rare that people change them
local build_file_names = { 'BUILD', 'BUILD.plz' }

-- look for a target in a file and return line, col, and whether it was found
local function find_target_in_file(filepath, target)
  local bufnr = vim.fn.bufnr(filepath, true) -- this creates the buffer as unlisted if it doesn't exist
  local parser = treesitter.get_parser(bufnr, 'python')
  local tree = parser:parse()[1]
  local query = treesitter_query.parse_query('python', string.format(build_target_query, target))

  for id, node in query:iter_captures(tree:root(), bufnr) do
    local name = query.captures[id]
    if name == 'call' then
      local line, col = ts_utils.get_vim_range({ node:range() }, bufnr)
      return line, col, true
    end
  end

  return nil, nil, false
end

---Returns the location of a build target. If the location of the target in the BUILD file can't be found (might be
---dynamically created), then line and column will be 1 and 1.
---@param root string an absolute path to the repo root
---@param label string: a build label of the form //path/to/pkg:target
---@return string: an absolute path to the BUILD file
---@return number: the line that the build target definition starts
---@return number: the column that the build target definition starts
---@return string|nil: error if any, this should be checked before using the other return values
parsing.locate_build_target = function(root, label)
  -- TODO: do this with the plz LSP instead?
  local root_obj = Path:new(root)
  if not root_obj:is_absolute() then
    error(string.format('root must be absolute, got "%s"', root))
  end

  -- I'm not actually sure what characters are allowed in a label so we won't bother filtering out anything unless it's
  -- obviously wrong like : in the pkg or / in the target.
  if not label:match '^//[^:]*:[^/]+$' then
    error(string.format('label must be in //path/to/pkg:target format, got "%s"', label))
  end

  local pkg, target = label:match '^//([^:]*):([^/]+)$'
  local pkg_path = root_obj:joinpath(pkg)
  for _, build_file_name in ipairs(build_file_names) do
    local build_path = pkg_path:joinpath(build_file_name)
    if build_path:exists() then
      local filepath = vim.fn.simplify(build_path.filename)
      local line, col, found = find_target_in_file(filepath, target)
      if found then
        return filepath, line, col, nil
      else
        return filepath, 1, 1, nil
      end
    end
  end

  return nil, nil, nil, string.format('no build file exists for package "%s"', pkg)
end

local supported_test_langs = { 'go' }

---Returns the name of the test under the cursor.
---Current supported languages are:
---- Go
---  - regular go tests
---  - testify suite test methods
---@return string
---@return string|nil: error if any, this should be checked before using the test name
parsing.get_test_at_cursor = function()
  if not vim.tbl_contains(supported_test_langs, vim.bo.filetype) then
    error(string.format('finding tests is not supported for %s files', vim.bo.filetype))
  end
  local current_node = ts_utils.get_node_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  while current_node:parent() do
    local node_type = current_node:type()
    if node_type == 'function_declaration' or node_type == 'method_declaration' then
      local identifier_node = current_node:field('name')[1] -- there will only be one child called name
      local func_name = ts_utils.get_node_text(identifier_node, bufnr)[1] -- there will only be one line
      -- we could also test if it has a single arg like *testing.T but this is probably enough, i think go test shouts
      -- at you if you provide a func starting with Test with the wrong signature anyway
      if func_name:sub(1, 4) == 'Test' then
        return (node_type == 'method_declaration' and '/' or '') .. func_name
      end
    end
    current_node = current_node:parent()
  end
  return nil, 'cursor is not in a test function'
end

return parsing