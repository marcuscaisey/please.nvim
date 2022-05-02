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

-- look for a target in a file and return the position (line, col), and whether it was found
local function find_target_in_file(filepath, target)
  local bufnr = vim.fn.bufnr(filepath, true) -- this creates the buffer as unlisted if it doesn't exist
  local parser = treesitter.get_parser(bufnr, 'python')
  local tree = parser:parse()[1]
  local query = treesitter_query.parse_query('python', make_build_target_query(target))

  for id, node in query:iter_captures(tree:root(), bufnr) do
    local name = query.captures[id]
    if name == 'target' then
      local start_row, start_col = ts_utils.get_vim_range({ node:range() }, bufnr)
      return { start_row, start_col }, true
    end
  end

  return nil, false
end

---Returns the location of a build target. If the location of the target in the BUILD file can't be found (might be
---dynamically created), then position will be {1, 1}.
---@param root string an absolute path to the repo root
---@param label string: a build label of the form //path/to/pkg:target
---@return string: an absolute path to the BUILD file
---@return number[]: the position that the build target definition starts as a (1, 1)-indexed (line, col) tuple
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
      local position, found = find_target_in_file(filepath, target)
      if found then
        return filepath, position, nil
      else
        return filepath, { 1, 1 }, nil
      end
    end
  end

  return nil, nil, string.format('no build file exists for package "%s"', pkg)
end

-- TODO: add support for at least python and maybe javascript
local test_name_getters = {
  go = {
    test_func = function(node)
      if node:type() == 'function_declaration' then
        local identifier_node = node:field('name')[1]
        local func_name = treesitter_query.get_node_text(identifier_node, 0)
        if vim.startswith(func_name, 'Test') then
          return func_name, true
        end
      end
      return nil, false
    end,
    testify_suite_method = function(node)
      if node:type() == 'method_declaration' then
        local identifier_node = node:field('name')[1]
        local func_name = treesitter_query.get_node_text(identifier_node, 0)
        if vim.startswith(func_name, 'Test') then
          return '/' .. func_name, true
        end
      end
      return nil, false
    end,
  },
  python = {
    unittest_method = function(node)
      if node:type() == 'function_definition' then
        local func_name = treesitter_query.get_node_text(node:field('name')[1], 0)
        if vim.startswith(func_name, 'test_') then
          local block = node:parent()
          if block then
            local class = block:parent()
            if class and class:type() == 'class_definition' then
              local class_name = treesitter_query.get_node_text(class:field('name')[1], 0)
              if vim.startswith(class_name, 'Test') then
                return string.format('%s.%s', class_name, func_name), true
              end
            end
          end
        end
      end
      return nil, false
    end,
  },
}

---Returns the name of the test under the cursor.
---Current supported languages are:
---- Go
---  - regular go tests
---  - testify suite test methods
---@return string
---@return string|nil: error if any, this should be checked before using the test name
parsing.get_test_at_cursor = function()
  logging.debug 'parsing.get_test_at_cursor called'

  local getters = test_name_getters[vim.bo.filetype]
  if not getters then
    error(string.format('finding tests is not supported for %s files', vim.bo.filetype))
  end

  local current_node = ts_utils.get_node_at_cursor()
  while current_node do
    for _, get_test_name in ipairs(vim.tbl_values(getters)) do
      local test_name, ok = get_test_name(current_node)
      if ok then
        return test_name, nil
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

  local tree = treesitter.get_parser(0, 'python'):parse()[1]
  local query = treesitter_query.parse_query('python', make_build_target_query())

  local cursor_pos = cursor.get()
  for _, match in query:iter_matches(tree:root(), 0) do
    local captured_nodes = extract_captures_from_match(match, query)

    if position_in_node_range(cursor_pos, captured_nodes.target) then
      local name = treesitter_query.get_node_text(captured_nodes.name, 0)
      return name:match '^"(.+)"$', nil
    end
  end

  return nil, 'cursor is not in a build target definition'
end

return parsing
