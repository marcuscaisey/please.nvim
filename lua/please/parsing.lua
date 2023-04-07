local Path = require('plenary.path')
local treesitter = require('vim.treesitter')
local treesitter_query = require('vim.treesitter.query')
local ts_utils = require('nvim-treesitter.ts_utils')
local logging = require('please.logging')
local cursor = require('please.cursor')

-- vim.treesitter.query.parse_query is deprecated since nvim 0.9
local parse_query = vim.treesitter.query.parse or treesitter_query.parse_query

local parsing = {}

-- makes a query which selects build targets, accepting an optional name arg which filters for build targets with the
-- given name
local make_build_target_query = function(name)
  local query = [[
    (call
      function: (identifier) @rule
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
  local query = parse_query('python', make_build_target_query(target))

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
  logging.log_call('parsing.locate_build_target')

  local root_obj = Path:new(root)

  local pkg, target = label:match('^//([^:]*):([^/]+)$')
  local pkg_path = root_obj:joinpath(pkg)
  for _, build_file_name in ipairs(build_file_names) do
    local build_path = pkg_path:joinpath(build_file_name)
    if build_path:exists() and build_path:is_file() then
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

-- extracts the captured nodes from a match returned from Query:iter_matches
local extract_captures_from_match = function(match, query)
  local captured_nodes = {}
  for id, node in pairs(match) do
    local name = query.captures[id]
    captured_nodes[name] = node
  end
  return captured_nodes
end

-- checks if the cursor is in a given treesitter node's range (inclusive ends)
local cursor_in_node_range = function(node)
  local cursor_pos = cursor.get()
  local row, col = cursor_pos.row, cursor_pos.col
  local start_row, start_col, end_row, end_col = ts_utils.get_vim_range({ node:range() })
  return (row == start_row and col >= start_col)
    or (start_row < row and row < end_row)
    or (row == end_row and col <= end_col)
end

-- TODO: extract these out into $runtimepath/lua/queries?
local find_test_configs = {
  go = {
    test_func = {
      query = [[
        (function_declaration
          name: (
            (identifier) @name
            (#match? @name "^Test.+"))
          parameters: (parameter_list
            (parameter_declaration
              name: (identifier)
              type: (
                (pointer_type) @param_type
                (#eq? @param_type "*testing.T"))))) @test
      ]],
      get_test_name = function(captures)
        return treesitter_query.get_node_text(captures.name, 0)
      end,
      get_test_selector = function(captures)
        local name = treesitter_query.get_node_text(captures.name, 0)
        return '^' .. name .. '$'
      end,
    },
    test_func_sub_test = {
      query = [[
        (function_declaration
          name: (
            (identifier) @test_func_name
            (#match? @test_func_name "^Test.+"))
          parameters: (parameter_list
            (parameter_declaration
              name: (identifier) @_t_param
              type: (
                (pointer_type) @_t_param_type
                (#eq? @_t_param_type "*testing.T"))))
          body: (block [
            (var_declaration
              (var_spec
                name: (identifier) @_test_cases_var
                value: (expression_list
                  (composite_literal
                    type: (slice_type
                      element: (struct_type
                        (field_declaration_list
                          . (field_declaration
                            name: (field_identifier) @_test_case_struct_name_field
                            type: (type_identifier) @_test_case_struct_name_type)
                          (#eq? @_test_case_struct_name_type "string"))))
                    body: (literal_value
                      (literal_element
                        (literal_value
                          (keyed_element
                            (literal_element
                              (identifier) @_test_case_name_field)
                            (literal_element
                              (interpreted_string_literal) @test_case_name))
                          (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test )))))
            (short_var_declaration
              left: (expression_list
                (identifier) @_test_cases_var)
              right: (expression_list
                (composite_literal
                  type: (slice_type
                    element: (struct_type
                      (field_declaration_list
                        . (field_declaration
                          name: (field_identifier) @_test_case_struct_name_field
                          type: (type_identifier) @_test_case_struct_name_type)
                        (#eq? @_test_case_struct_name_type "string"))))
                  body: (literal_value
                    (literal_element
                      (literal_value
                        (keyed_element
                          (literal_element
                            (identifier) @_test_case_name_field)
                          (literal_element
                            (interpreted_string_literal) @test_case_name))
                        (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test ))))
            ]
            (for_statement
              (range_clause
                left: (expression_list
                  (identifier) @_test_cases_loop_var . )
                right: (identifier) @_test_cases_loop_range_var)
              (#eq? @_test_cases_loop_range_var @_test_cases_var)
              body: (block
                (call_expression
                  function: (selector_expression
                    operand: (identifier) @_t_run_operand
                    field: (field_identifier) @_t_run)
                  (#eq? @_t_run_operand @_t_param)
                  (#eq? @_t_run "Run")
                  arguments: (argument_list
                    (selector_expression
                      operand: (identifier) @_run_method_name_arg_operand
                      field: (field_identifier) @_run_method_name_arg_field)
                    (#eq? @_run_method_name_arg_operand @_test_cases_loop_var)
                    (#eq? @_run_method_name_arg_field @_test_case_struct_name_field)))))))
      ]],
      get_test_name = function(captures)
        local test_case_name = treesitter_query.get_node_text(captures.test_case_name, 0):match('"(.+)"')
        local test_func_name = treesitter_query.get_node_text(captures.test_func_name, 0)
        return test_func_name .. '/' .. test_case_name:gsub(' ', '_')
      end,
      get_test_selector = function(captures)
        local test_case_name = treesitter_query.get_node_text(captures.test_case_name, 0):match('"(.+)"')
        local test_func_name = treesitter_query.get_node_text(captures.test_func_name, 0)
        return '^' .. test_func_name .. '$/^' .. test_case_name:gsub(' ', '_') .. '$'
      end,
    },
    testify_suite_method = {
      query = [[
        (method_declaration
          name: (
            (field_identifier) @name
            (#match? @name "^Test.+"))) @test
      ]],
      get_test_name = function(captures)
        return treesitter_query.get_node_text(captures.name, 0)
      end,
      get_test_selector = function(captures)
        local name = treesitter_query.get_node_text(captures.name, 0)
        return '/^' .. name .. '$'
      end,
    },
    testify_suite_method_sub_test = {
      query = [[
        (method_declaration
          receiver: (parameter_list
            (parameter_declaration
              name: (identifier) @_receiver))
          name: (
            (field_identifier) @test_method_name
            (#match? @test_method_name "^Test.+"))
          body: (block [
            (var_declaration
              (var_spec
                name: (identifier) @_test_cases_var
                value: (expression_list
                  (composite_literal
                    type: (slice_type
                      element: (struct_type
                        (field_declaration_list
                          . (field_declaration
                            name: (field_identifier) @_test_case_struct_name_field
                            type: (type_identifier) @_test_case_struct_name_type)
                          (#eq? @_test_case_struct_name_type "string"))))
                    body: (literal_value
                      (literal_element
                        (literal_value
                          (keyed_element
                            (literal_element
                              (identifier) @_test_case_name_field)
                            (literal_element
                              (interpreted_string_literal) @test_case_name))
                          (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test )))))
            (short_var_declaration
              left: (expression_list
                (identifier) @_test_cases_var)
              right: (expression_list
                (composite_literal
                  type: (slice_type
                    element: (struct_type
                      (field_declaration_list
                        . (field_declaration
                          name: (field_identifier) @_test_case_struct_name_field
                          type: (type_identifier) @_test_case_struct_name_type)
                        (#eq? @_test_case_struct_name_type "string"))))
                  body: (literal_value
                    (literal_element
                      (literal_value
                        (keyed_element
                          (literal_element
                            (identifier) @_test_case_name_field)
                          (literal_element
                            (interpreted_string_literal) @test_case_name))
                        (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test ))))
            ]
            (for_statement
              (range_clause
                left: (expression_list
                  (identifier) @_test_cases_loop_var . )
                right: (identifier) @_test_cases_loop_range_var)
              (#eq? @_test_cases_loop_range_var @_test_cases_var)
              body: (block
                (call_expression
                  function: (selector_expression
                    operand: (identifier) @_receiver_run_operand
                    field: (field_identifier) @_receiver_run)
                  (#eq? @_receiver_run_operand @_receiver)
                  (#eq? @_receiver_run "Run")
                  arguments: (argument_list
                    (selector_expression
                      operand: (identifier) @_run_method_name_arg_operand
                      field: (field_identifier) @_run_method_name_arg_field)
                    (#eq? @_run_method_name_arg_operand @_test_cases_loop_var)
                    (#eq? @_run_method_name_arg_field @_test_case_struct_name_field)))))))
      ]],
      get_test_name = function(captures)
        local test_case_name = treesitter_query.get_node_text(captures.test_case_name, 0):match('"(.+)"')
        local test_method_name = treesitter_query.get_node_text(captures.test_method_name, 0)
        return test_method_name .. '/' .. test_case_name:gsub(' ', '_')
      end,
      get_test_selector = function(captures)
        local test_case_name = treesitter_query.get_node_text(captures.test_case_name, 0):match('"(.+)"')
        local test_method_name = treesitter_query.get_node_text(captures.test_method_name, 0)
        return '/^' .. test_method_name .. '$/^' .. test_case_name:gsub(' ', '_') .. '$'
      end,
    },
  },
  python = {
    unittest_method = {
      query = [[
        ;; query
        (class_definition
          name: (
            (identifier) @class_name)
          body: (block
            [
              (function_definition
                name: (identifier) @name
                (#match? @name "^test_.+")) @test
              (decorated_definition
                definition: (function_definition
                  name: (identifier) @name
                  (#match? @name "^test_.+"))) @test
            ]))
      ]],
      get_test_name = function(captures)
        local class_name = treesitter_query.get_node_text(captures.class_name, 0)
        local name = treesitter_query.get_node_text(captures.name, 0)
        return class_name .. '.' .. name
      end,
      get_test_selector = function(captures)
        local class_name = treesitter_query.get_node_text(captures.class_name, 0)
        local name = treesitter_query.get_node_text(captures.name, 0)
        return class_name .. '.' .. name
      end,
    },
  },
}

---@class Test
---@field name string: the name of the test
---@field selector string: the selector that can be used to select only that test for running

---Returns the selector for the test under the cursor.
---Current supported languages are:
---- Go
---  - regular test functions (not subtests)
---  - testify suite test methods (not subtests)
---  - table tests
---- Python
---  - unittest test methods
---@return Test
---@return string|nil: error if any, this should be checked before using the test name
parsing.get_test_at_cursor = function()
  logging.log_call('parsing.get_test_at_cursor')

  local configs = find_test_configs[vim.bo.filetype]
  if not configs then
    return nil, string.format('finding tests is not supported for %s files', vim.bo.filetype)
  end

  local tree = treesitter.get_parser(0, vim.bo.filetype):parse()[1]
  for _, config in ipairs(vim.tbl_values(configs)) do
    local query = parse_query(vim.bo.filetype, config.query)
    for _, match in query:iter_matches(tree:root(), 0) do
      local captures = extract_captures_from_match(match, query)
      if cursor_in_node_range(captures.test) then
        return {
          name = config.get_test_name(captures),
          selector = config.get_test_selector(captures),
        }
      end
    end
  end

  return nil, 'cursor is not in a test function'
end

---Returns the tests from the current file.
---Current supported languages are:
---- Go
---  - regular test functions (not subtests)
---  - testify suite test methods (not subtests)
---  - table tests
---- Python
---  - unittest test methods
---@return Test[]
---@return string|nil: error if any, this should be checked before using the tests
parsing.list_tests_in_file = function()
  logging.log_call('parsing.list_tests_in_file')

  local configs = find_test_configs[vim.bo.filetype]
  if not configs then
    return nil, string.format('listing tests is not supported for %s files', vim.bo.filetype)
  end

  local tests = {}
  local tree = treesitter.get_parser(0, vim.bo.filetype):parse()[1]
  for _, config in ipairs(vim.tbl_values(configs)) do
    local query = parse_query(vim.bo.filetype, config.query)
    for _, match in query:iter_matches(tree:root(), 0) do
      local captures = extract_captures_from_match(match, query)
      table.insert(tests, {
        row = captures.test:start(),
        name = config.get_test_name(captures),
        selector = config.get_test_selector(captures),
      })
    end
  end

  if #tests == 0 then
    return nil, string.format('%s contains no tests', vim.fn.expand('%:t'))
  end

  table.sort(tests, function(a, b)
    return a.row < b.row
  end)

  return vim.tbl_map(function(test)
    return {
      name = test.name,
      selector = test.selector,
    }
  end, tests)
end

local build_label = function(root, build_file, target)
  local pkg = Path:new(build_file):parent():make_relative(root)
  if pkg == '.' then
    pkg = ''
  end
  return string.format('//%s:%s', pkg, target)
end

---Returns the label and rule of the build target under the cursor.
---@param root string: an absolute path to the repo root
---@return string: a build label
---@return string: a build rule
---@return string|nil: error if any, this should be checked before using the label and rule
-- TODO: return a table instead of multiple values
parsing.get_target_at_cursor = function(root)
  logging.log_call('parsing.get_target_at_cursor')

  local tree = treesitter.get_parser(0, 'python'):parse()[1]
  local query = parse_query('python', make_build_target_query())

  for _, match in query:iter_matches(tree:root(), 0) do
    local captures = extract_captures_from_match(match, query)
    if cursor_in_node_range(captures.target) then
      local name = treesitter_query.get_node_text(captures.name, 0)
      -- name returned by treesitter is surrounded by quotes
      if name:sub(1, 1) == '"' then
        name = name:match('^"(.+)"$')
      else
        name = name:match("^'(.+)'$")
      end
      local rule = treesitter_query.get_node_text(captures.rule, 0)
      local build_file = vim.fn.expand('%:p')
      return build_label(root, build_file, name), rule, nil
    end
  end

  return nil, nil, 'cursor is not in a build target definition'
end

return parsing
