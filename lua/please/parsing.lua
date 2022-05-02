local Path = require 'plenary.path'
local treesitter = require 'vim.treesitter'
local treesitter_query = require 'vim.treesitter.query'
local ts_utils = require 'nvim-treesitter.ts_utils'
local logging = require 'please.logging'
local cursor = require 'please.cursor'

local parsing = {}

-- makes a query which selects build targets, accepting an optional name arg which filters for build targets with the
-- given name
local make_build_target_query = function(name)
  local query = [[
    (call
      function: (identifier)
      arguments: (argument_list
        (keyword_argument
          name: (
            (identifier) @kwarg
            (#eq? @kwarg "name"))
          value: (
            (string) @name
            %s)))) @target
  ]]

  local name_predicate
  if name then
    name_predicate = string.format('(#eq? @name "\\"%s\\"")', name)
  else
    name_predicate = ''
  end

  return string.format(query, name_predicate)
end

-- TODO: should we get these from the .plzconfig? feels like it should be really rare that people change them
local build_file_names = { 'BUILD', 'BUILD.plz' }

-- look for a target in a file and return line, col, and whether it was found
local function find_target_in_file(filepath, target)
  local bufnr = vim.fn.bufnr(filepath, true) -- this creates the buffer as unlisted if it doesn't exist
  local parser = treesitter.get_parser(bufnr, 'python')
  local tree = parser:parse()[1]
  local query = treesitter_query.parse_query('python', make_build_target_query(target))

  for id, node in query:iter_captures(tree:root(), bufnr) do
    local name = query.captures[id]
    if name == 'target' then
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
  logging.debug(string.format('parsing.locate_build_target called with root=%s, label=%s', root, label))

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
  logging.debug 'parsing.get_test_at_cursor called'

  if not vim.tbl_contains(supported_test_langs, vim.bo.filetype) then
    error(string.format('finding tests is not supported for %s files', vim.bo.filetype))
  end
  local current_node = ts_utils.get_node_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  while current_node and current_node:parent() do
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

-- extracts the captured nodes from a match returned from Query:iter_matches
local extract_captures_from_match = function(match, query)
  local captured_nodes = {}
  for id, node in pairs(match) do
    local name = query.captures[id]
    captured_nodes[name] = node
  end
  return captured_nodes
end

-- checks if a position is in a given range (inclusive ends)
local position_in_node_range = function(position, node, bufnr)
  local row, col = unpack(position)
  local start_row, start_col, end_row, end_col = ts_utils.get_vim_range({ node:range() }, bufnr)
  return (row == start_row and col >= start_col)
    or (start_row < row and row < end_row)
    or (row == end_row and col <= end_col)
end

---Returns the name of the build target under the cursor.
---@return string: a build target
---@return string|nil: error if any, this should be checked before using the build target
parsing.get_target_at_cursor = function()
  if vim.bo.filetype ~= 'please' then
    error(string.format('file (%s) is not a BUILD file', vim.bo.filetype))
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local tree = treesitter.get_parser(bufnr, 'python'):parse()[1]
  local query = treesitter_query.parse_query('python', make_build_target_query())

  local cursor_pos = cursor.get()
  for _, match in query:iter_matches(tree:root(), bufnr) do
    local captured_nodes = extract_captures_from_match(match, query)

    if position_in_node_range(cursor_pos, captured_nodes.target, bufnr) then
      local name = treesitter_query.get_node_text(captured_nodes.name, bufnr)
      return name:match '^"(.+)"$', nil
    end
  end

  return nil, 'cursor is not in a build target definition'
end

return parsing
