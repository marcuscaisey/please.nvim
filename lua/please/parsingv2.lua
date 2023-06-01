local cursor = require('please.cursor')
local logging = require('please.logging')

local M = {}

---Language agnostic representation of a test and its children. A Test along with its children forms a tree of Tests.
---@private
---@class please.parsing.Test
---@field name string
---@field selector string The string which should be passed to the test runner to run this test.
---@field start please.cursor.Position The start position of the test.
---@field end_ please.cursor.Position The end position of the test.
---@field children please.parsing.Test[]
local Test = {}

---@param test {name: string, selector: string, node: TSNode, children: please.parsing.Test[]}
---@return please.parsing.Test
function Test:new(test)
  self.__index = self
  local start_row, start_col, end_row, end_col = test.node:range()
  return setmetatable({
    name = test.name,
    selector = test.selector,
    start = { row = start_row + 1, col = start_col + 1 },
    end_ = { row = end_row + 1, col = end_col },
    children = test.children or {},
  }, self)
end

---Returns whether the test (including start and end) contains the given position.
---@param pos please.cursor.Position
---@return boolean
function Test:contains(pos)
  return (pos.row == self.start.row and self.start.col <= pos.col)
    or (self.start.row < pos.row and pos.row < self.end_.row)
    or (pos.row == self.end_.row and pos.col <= self.end_.col)
end

---Performs a pre-order depth traversal of the test tree, calling the given function with each test.
---@param f fun(test: please.parsing.Test)
function Test:for_each(f)
  f(self)
  for _, child in ipairs(self.children) do
    child:for_each(f)
  end
end

---@param query Query
---@param node TSNode
---@return table<string, TSNode>[]
local query_matches_in_node = function(query, node)
  local matches = {} ---@type table<string, TSNode>[]
  local node_start_row, _, node_stop_row, _ = node:range()
  for _, match in query:iter_matches(node, 0, node_start_row, node_stop_row, { max_start_depth = 1 }) do
    local captured_nodes = {}
    for id, captured_node in pairs(match) do
      local name = query.captures[id]
      captured_nodes[name] = captured_node
    end
    table.insert(matches, captured_nodes)
  end
  return matches
end

local test_func_subtest_query = vim.treesitter.query.parse(
  'go',
  [[
  (
    (parameter_list
      (parameter_declaration
        name: (identifier) @_t_param))
    (block
      (call_expression
        function: (selector_expression
          operand: (identifier) @_call_operand
          field: (field_identifier) @_call_field)
          (#eq? @_call_operand @_t_param)
          (#eq? @_call_field "Run")
        arguments: (argument_list
          (interpreted_string_literal) @name
          (func_literal
            body: (block) @body))) @subtest)
   )
  ]]
)

local test_func_table_test_query = vim.treesitter.query.parse(
  'go',
  [[
  (
    (parameter_list
      (parameter_declaration
        name: (identifier) @_t_param))
    (block [
      (var_declaration
        (var_spec
          name: (identifier) @_test_cases_var
          value: (expression_list
            (composite_literal
              type: (slice_type
                element: (struct_type
                  (field_declaration_list
                    (field_declaration
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
                        (interpreted_string_literal) @name))
                    (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case)))))
      (short_var_declaration
        left: (expression_list
          (identifier) @_test_cases_var)
        right: (expression_list
          (composite_literal
            type: (slice_type
              element: (struct_type
                (field_declaration_list
                  (field_declaration
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
                      (interpreted_string_literal) @name))
                  (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case))))
      ]
      (for_statement
        (range_clause
          left: (expression_list
            (identifier) @_test_cases_loop_var .)
          right: (identifier) @_test_cases_loop_range_var)
        (#eq? @_test_cases_loop_range_var @_test_cases_var)
        body: (block
          (call_expression
            function: (selector_expression
              operand: (identifier) @_call_operand
              field: (field_identifier) @_call_field)
            (#eq? @_call_operand @_t_param)
            (#eq? @_call_field "Run")
            arguments: (argument_list
              (selector_expression
                operand: (identifier) @_name_arg_operand
                field: (field_identifier) @_name_arg_field)
              (#eq? @_name_arg_operand @_test_cases_loop_var)
              (#eq? @_name_arg_field @_test_case_struct_name_field)
              (func_literal
                body: (block)))))) @for_loop)
  )
  ]]
)

local parse_test_func_subtests

---@param parent_name string
---@param parent_selector string
---@param parent_test TSNode
---@param parent_body TSNode
---@return please.parsing.Test[]
parse_test_func_subtests = function(parent_name, parent_selector, parent_test, parent_body)
  local subtests = {} ---@type please.parsing.Test[]

  local subtest_matches = query_matches_in_node(test_func_subtest_query, parent_test)
  for _, captures in ipairs(subtest_matches) do
    -- We make sure that the subtest is a direct child of parent_body so that we don't pick up any nested
    -- subtests which will be picked up by recursive calls of parse_subtests.
    if captures.subtest:parent():id() == parent_body:id() then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local subtest_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. subtest_name
      local selector = parent_selector .. '/^' .. subtest_name .. '$'
      table.insert(
        subtests,
        Test:new({
          name = name,
          selector = selector,
          node = captures.subtest,
          children = parse_test_func_subtests(name, selector, captures.subtest, captures.body),
        })
      )
    end
  end

  local table_test_matches = query_matches_in_node(test_func_table_test_query, parent_test)
  for _, captures in ipairs(table_test_matches) do
    -- We make sure that the for loop part of the table test is a direct child of parent_body so that we don't pick
    -- up any nested table tests which will be picked up by recursive calls of parse_subtests.
    if captures.for_loop:parent():id() == parent_body:id() then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local test_case_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. test_case_name
      local selector = parent_selector .. '/^' .. test_case_name .. '$'
      table.insert(
        subtests,
        Test:new({
          name = name,
          selector = selector,
          node = captures.test_case,
        })
      )
    end
  end

  return subtests
end

local test_func_query = vim.treesitter.query.parse(
  'go',
  [[
  (function_declaration
    (identifier) @name
    (#match? @name "^Test.+")
    parameters: (parameter_list
      (parameter_declaration
        name: (identifier)
        type: (
          (pointer_type) @_t_param_type
          (#eq? @_t_param_type "*testing.T"))))
    body: (block) @body) @test
  ]]
)

---@param root_node TSNode
---@return please.parsing.Test?
local parse_test_func = function(root_node)
  local matches = query_matches_in_node(test_func_query, root_node)
  if #matches == 0 then
    return
  end
  local captures = matches[1]
  local name = vim.treesitter.get_node_text(captures.name, 0)
  local selector = '^' .. name .. '$'
  return Test:new({
    name = name,
    selector = selector,
    node = captures.test,
    children = parse_test_func_subtests(name, selector, captures.test, captures.body),
  })
end

local test_method_subtest_query = vim.treesitter.query.parse(
  'go',
  [[
    (call_expression
      function: (selector_expression
        operand: (identifier) @receiver
        field: (field_identifier) @_field)
        (#eq? @_field "Run")
      arguments: (argument_list
        (interpreted_string_literal) @name
        (func_literal
          body: (block) @body))) @subtest
  ]]
)

local test_method_table_test_query = vim.treesitter.query.parse(
  'go',
  [[
    (
      [
        (var_declaration
          (var_spec
            name: (identifier) @_test_cases_var
            value: (expression_list
              (composite_literal
                type: (slice_type
                  element: (struct_type
                    (field_declaration_list
                      (field_declaration
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
                          (interpreted_string_literal) @name))
                      (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case)))))
        (short_var_declaration
          left: (expression_list
            (identifier) @_test_cases_var)
          right: (expression_list
            (composite_literal
              type: (slice_type
                element: (struct_type
                  (field_declaration_list
                    (field_declaration
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
                        (interpreted_string_literal) @name))
                    (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case))))
      ]
      (for_statement
        (range_clause
          left: (expression_list
            (identifier) @_test_cases_loop_var .)
          right: (identifier) @_test_cases_loop_range_var)
        (#eq? @_test_cases_loop_range_var @_test_cases_var)
        body: (block
          (call_expression
            function: (selector_expression
              operand: (identifier) @receiver
              field: (field_identifier) @_call_field)
            (#eq? @_call_field "Run")
            arguments: (argument_list
              (selector_expression
                operand: (identifier) @_name_arg_operand
                field: (field_identifier) @_name_arg_field)
              (#eq? @_name_arg_operand @_test_cases_loop_var)
              (#eq? @_name_arg_field @_test_case_struct_name_field)
              (func_literal
                body: (block)))))) @for_loop)
  ]]
)

local parse_test_method_subtests

---@param parent_name string
---@param parent_selector string
---@param receiver string
---@param parent_body TSNode
---@return please.parsing.Test[]
parse_test_method_subtests = function(parent_name, parent_selector, receiver, parent_body)
  local subtests = {} ---@type please.parsing.Test[]

  -- TODO: inline query_matches_in_node
  local subtest_matches = query_matches_in_node(test_method_subtest_query, parent_body)
  for _, captures in ipairs(subtest_matches) do
    print(string.format('%s: %s', parent_name, vim.treesitter.get_node_text(captures.name, 0)))
    -- We make sure that the subtest is a direct child of parent_body so that we don't pick up any nested subtests which
    -- will be picked up by recursive calls of parse_test_method_subtests. Passing max_start_depth = 1 to iter_matches
    -- achieves the same thing but is not released yet, so we do both for now.
    -- TODO: remove the extra check when minimum nvim version is 0.10
    if
      captures.subtest:parent():id() == parent_body:id()
      and vim.treesitter.get_node_text(captures.receiver, 0) == receiver
    then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local subtest_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. subtest_name
      local selector = parent_selector .. '/^' .. subtest_name .. '$'
      table.insert(
        subtests,
        Test:new({
          name = name,
          selector = selector,
          node = captures.subtest,
          children = parse_test_method_subtests(name, selector, receiver, captures.body),
        })
      )
    end
  end

  local table_test_matches = query_matches_in_node(test_method_table_test_query, parent_body)
  for _, captures in ipairs(table_test_matches) do
    -- We make sure that the subtest is a direct child of parent_body so that we don't pick up any nested subtests which
    -- will be picked up by recursive calls of parse_test_method_subtests. Passing max_start_depth = 1 to iter_matches
    -- achieves the same thing but is not released yet, so we do both for now.
    -- TODO: remove the extra check when minimum nvim version is 0.10
    if
      captures.for_loop:parent():id() == parent_body:id()
      and vim.treesitter.get_node_text(captures.receiver, 0) == receiver
    then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local test_case_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. test_case_name
      local selector = parent_selector .. '/^' .. test_case_name .. '$'
      table.insert(
        subtests,
        Test:new({
          name = name,
          selector = selector,
          node = captures.test_case,
        })
      )
    end
  end

  return subtests
end

local test_method_query = vim.treesitter.query.parse(
  'go',
  [[
    (method_declaration
      receiver: (parameter_list
        (parameter_declaration
          name: (identifier) @receiver))
      name: (field_identifier) @name
      body: (block) @body) @test
  ]]
)

---@param root_node TSNode
---@return please.parsing.Test?
local parse_test_method = function(root_node)
  local matches = query_matches_in_node(test_method_query, root_node)
  if #matches == 0 then
    return
  end
  local captures = matches[1]
  local parent_name = vim.treesitter.get_node_text(captures.name, 0)
  local parent_selector = '/^' .. parent_name .. '$'
  local receiver = vim.treesitter.get_node_text(captures.receiver, 0)
  local parent_body = captures.body
  return Test:new({
    name = parent_name,
    selector = parent_selector,
    node = captures.test,
    children = parse_test_method_subtests(parent_name, parent_selector, receiver, parent_body),
  })
end

---@type table<string, table<string, fun(root_node:TSNode):please.parsing.Test?>>
local parsers_by_node_type_by_filetype = {
  go = {
    function_declaration = parse_test_func,
    method_declaration = parse_test_method,
  },
}

---Returns the test at the current cursor position.
---Current supported languages are:
---- Go
---  - test functions
---  - subtests
---  - table tests
---@return {name:string, selector:string}[]? tests
---@return string? error if any, this should be checked before using the tests
M.get_test_at_cursor = function()
  logging.log_call('please.parsing.get_test_at_cursor')

  local parsers_by_node_type = parsers_by_node_type_by_filetype[vim.bo.filetype]
  if not parsers_by_node_type then
    return nil, string.format('finding tests is not supported for %s files', vim.bo.filetype)
  end

  local root_node = vim.treesitter.get_node()
  while root_node and not parsers_by_node_type[root_node:type()] do
    root_node = root_node:parent()
  end
  if not root_node then
    return nil, 'cursor is not in a test'
  end

  local parser = parsers_by_node_type[root_node:type()]
  local parent_test = parser(root_node)
  if not parent_test then
    return nil, 'cursor is not in a test'
  end

  local current_pos = cursor.get()
  local test ---@type please.parsing.Test
  parent_test:for_each(function(t)
    if t:contains(current_pos) then
      test = t
    end
  end)

  return { name = test.name, selector = test.selector }
end

return M
