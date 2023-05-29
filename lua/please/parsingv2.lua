local cursor = require('please.cursor')
local logging = require('please.logging')

local M = {}

---A range of cursor positions.
---@class please.parsing.Range
---@field start please.cursor.Position
---@field end_ please.cursor.Position
local Range = {}

---@param start please.cursor.Position
---@param end_ please.cursor.Position
---@return please.parsing.Range
function Range:new(start, end_)
  self.__index = self
  return setmetatable({ start = start, end_ = end_ }, self)
end

---@param node TSNode
---@return please.parsing.Range
function Range.from_node(node)
  local start_row, start_col, end_row, end_col = node:range()
  local start = { row = start_row + 1, col = start_col + 1 }
  local end_ = { row = end_row + 1, col = end_col }
  return Range:new(start, end_)
end

---Returns whether the range (including the start and end) contains the given position.
---@param pos please.cursor.Position
---@return boolean
function Range:contains(pos)
  return (pos.row == self.start.row and self.start.col <= pos.col)
    or (self.start.row < pos.row and pos.row < self.end_.row)
    or (pos.row == self.end_.row and pos.col <= self.end_.col)
end

---Language agnostic representation of a test and its children. A Test along with its children forms a tree of tests.
---@class please.parsing.Test
---@field name string
---@field selector string The string which should be passed to the test runner to run this test.
---@field ranges please.parsing.Range[] The line ranges which this test covers. This will usually only contain a single range. An example of a test with multiple ranges is a Go table test where the definition of the test cases and the body of the t.Run call are separate ranges.
---@field children please.parsing.Test[]
local Test = {}

---@param test {name: string, selector: string, ranges: please.parsing.Range[], children: please.parsing.Test[]}
---@return please.parsing.Test
function Test:new(test)
  self.__index = self
  return setmetatable({
    name = test.name,
    selector = test.selector,
    ranges = test.ranges or {},
    children = test.children or {},
  }, self)
end

---Returns the list of tests obtained by performing a pre-order depth-first traversal of the test tree.
---@param filter? fun(test: please.parsing.Test):boolean Optional callback used to decide whether to include a test and its children.
---@return please.parsing.Test[]
function Test:traverse(filter)
  if filter and not filter(self) then
    return {}
  end

  local tests = { self } ---@type please.parsing.Test[]
  for _, child in ipairs(self.children) do
    for _, t in ipairs(child:traverse(filter)) do
      table.insert(tests, t)
    end
  end

  return tests
end

---@param query Query
---@param node TSNode
---@return table<string, TSNode>[]
local query_matches_in_node = function(query, node)
  local matches = {} -- table<string, tsnode>
  local node_start, _, node_stop, _ = node:range()
  for _, match in query:iter_matches(node, 0, node_start, node_stop) do
    local captured_nodes = {}
    for id, captured_node in pairs(match) do
      local name = query.captures[id]
      captured_nodes[name] = captured_node
    end
    table.insert(matches, captured_nodes)
  end
  return matches
end

local subtest_query = vim.treesitter.query.parse(
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

local table_test_query = vim.treesitter.query.parse(
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
                        (interpreted_string_literal) @name ))
                    (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case )))))
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
                      (interpreted_string_literal) @name ))
                  (#eq? @_test_case_name_field @_test_case_struct_name_field))) @test_case ))))
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
                body: (block) @subtest_body))) @subtest )) @for_loop )
  )
  ]]
)

local parse_subtests

---@param parent_name string
---@param parent_selector string
---@param parent_test_node TSNode
---@param parent_body_node TSNode
---@return please.parsing.Test[]
parse_subtests = function(parent_name, parent_selector, parent_test_node, parent_body_node)
  local subtests = {}

  local subtest_matches = query_matches_in_node(subtest_query, parent_test_node)
  if #subtest_matches > 0 then
    for _, captures in ipairs(subtest_matches) do
      -- We make sure that the subtest is a direct child of parent_body_node so that we don't pick up any nested
      -- subtests which will be picked up by recursive calls of parse_subtests.
      if captures.subtest:parent():id() == parent_body_node:id() then
        -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
        -- underscores since that's how the go test runner displays test names with spaces in.
        local subtest_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
        local name = parent_name .. '/' .. subtest_name
        local selector = parent_selector .. '/^' .. subtest_name .. '$'
        table.insert(
          subtests,
          Test:new({
            name = name,
            selector = selector,
            ranges = { Range.from_node(captures.subtest) },
            children = parse_subtests(name, selector, captures.subtest, captures.body),
          })
        )
      end
    end
  end

  local table_test_matches = query_matches_in_node(table_test_query, parent_test_node)
  for _, captures in ipairs(table_test_matches) do
    -- We make sure that the for loop part of the table test is a direct child of parent_body_node so that we don't pick
    -- up any nested table tests which will be picked up by recursive calls of parse_subtests.
    if captures.for_loop:parent():id() == parent_body_node:id() then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores since that's how the go test runner displays test names with spaces in.
      local test_case_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. test_case_name
      local selector = parent_selector .. '/^' .. test_case_name .. '$'
      table.insert(
        subtests,
        Test:new({
          name = name,
          selector = selector,
          ranges = { Range.from_node(captures.test_case), Range.from_node(captures.subtest) },
          -- TODO: we should only need to parse the nested subtests once since they are
          -- the same for each test case
          children = parse_subtests(name, selector, captures.subtest, captures.subtest_body),
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
    ranges = { Range.from_node(captures.test) },
    children = parse_subtests(name, selector, captures.test, captures.body),
  })
end

---@type table<string, table<string, fun(root_node:TSNode):please.parsing.Test?>>
local parsers_by_node_type_by_filetype = {
  go = {
    function_declaration = parse_test_func,
  },
}

---Returns the tests at the current cursor position.
---Current supported languages are:
---- Go
---  - test functions
---  - subtests
---  - table tests
---@return {name:string, selector:string}[]? tests
---@return string? error if any, this should be checked before using the tests
M.list_tests_at_cursor = function()
  logging.log_call('please.parsing.list_tests_at_cursor')

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

  local pos = cursor.get()
  local tests = parent_test:traverse(function(t)
    for _, range in ipairs(t.ranges) do
      if range:contains(pos) then
        return true
      end
    end
    return false
  end)
  return vim.tbl_map(function(test)
    return {
      name = test.name,
      selector = test.selector,
    }
  end, tests)
end

return M
