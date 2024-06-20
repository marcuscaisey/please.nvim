local logging = require('please.logging')

vim.treesitter.language.register('python', 'please')

local parsing = {}

---Checks if the parser for the given filetype is installed and if not prompts the user to install it.
---@param filetype string
local function check_parser_installed(filetype)
  local lang = vim.treesitter.language.get_lang(filetype) or filetype

  if pcall(vim.treesitter.language.add, lang) then
    return
  end

  local err_msg = string.format(
    'tree-sitter parser for %s%sis not installed.',
    lang,
    lang ~= filetype and string.format(' (used for %s files) ', filetype) or ' '
  )
  if
    vim.fn.exists(':TSInstallSync') == 2
    and vim.fn.confirm(err_msg .. ' Install now?', '&yes\n&no', 2, 'Question') == 1
  then
    vim.cmd.TSInstallSync(lang)
  else
    error(err_msg .. ' See :help treesitter-parsers')
  end
end

-- makes a query which selects build targets, accepting an optional name arg which filters for build targets with the
-- given name
local function make_build_target_query(name)
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

local function ts_range_to_nvim_range(ts_start_row, ts_start_col)
  -- treesitter ranges are (0, 0)-based
  -- nvim ranges are (1, 0)-based
  return { ts_start_row + 1, ts_start_col }
end

---Returns the location of a build target. If the location of the target in the BUILD file can't be found (might be
---dynamically created), then position will be {1, 0}.
---@param root string an absolute path to the repo root
---@param label string: a build label of the form //path/to/pkg:target
---@return string?: an absolute path to the BUILD file
---@return number[]?: the position that the build target definition starts as a (1, 0)-based (line, col) tuple
---@return string? errmsg
function parsing.locate_build_target(root, label)
  logging.log_call('parsing.locate_build_target')

  check_parser_installed('please')

  local pkg, target = label:match('^//([^:]*):([^/]+)$')
  local pkg_path = vim.fs.joinpath(root, pkg)
  for _, build_file_name in ipairs(build_file_names) do
    local build_path = vim.fs.joinpath(pkg_path, build_file_name)
    local stat = vim.uv.fs_stat(build_path)
    if stat and stat.type == 'file' then
      local filepath = vim.fs.normalize(build_path)

      local bufnr = vim.fn.bufnr(filepath, true) -- this creates the buffer as unlisted if it doesn't exist
      local parser = vim.treesitter.get_parser(bufnr, 'python')
      local tree = parser:parse()[1]
      local query = vim.treesitter.query.parse('python', make_build_target_query(target))

      for id, node in query:iter_captures(tree:root(), bufnr, nil, nil) do
        local name = query.captures[id]
        if name == 'target' then
          local ts_start_row, ts_start_col = node:range()
          return filepath, ts_range_to_nvim_range(ts_start_row, ts_start_col)
        end
      end

      return filepath, { 1, 0 }
    end
  end

  return nil, nil, string.format('no build file exists for package "%s"', pkg)
end

-- extracts the captured nodes from a match returned from Query:iter_matches
local function extract_captures_from_match(match, query)
  local captured_nodes = {}
  for id, node in pairs(match) do
    local name = query.captures[id]
    captured_nodes[name] = node
  end
  return captured_nodes
end

-- checks if the cursor is in a given treesitter node's range (inclusive ends)
local function cursor_in_node_range(node)
  local pos = vim.api.nvim_win_get_cursor(0)
  return vim.treesitter.is_in_node_range(node, pos[1] - 1, pos[2])
end

---Language agnostic representation of a test and its children. A Test along with its children forms a tree of Tests.
---@private
---@class please.parsing.Test
---@field name string
---@field selector string The string which should be passed to the test runner to run this test.
---@field start integer[] The (1, 0)-based start position of the test.
---@field end_ integer[] The (1, 0)-based end position of the test.
---@field children please.parsing.Test[]
local Test = {}

---@param name string
---@param selector string
---@param node TSNode
---@param children please.parsing.Test[]?
---@return please.parsing.Test
function Test:new(name, selector, node, children)
  self.__index = self
  local start_row, start_col, end_row, end_col = node:range()
  return setmetatable({
    name = name,
    selector = selector,
    start = ts_range_to_nvim_range(start_row, start_col),
    end_ = ts_range_to_nvim_range(end_row, end_col),
    children = children or {},
  }, self)
end

---Returns whether the test (including start and end) contains the given position.
---@param pos integer[] {row, col}
---@return boolean
function Test:contains(pos)
  return (pos[1] == self.start[1] and self.start[2] <= pos[2])
    or (self.start[1] < pos[1] and pos[1] < self.end_[1])
    or (pos[1] == self.end_[1] and pos[2] <= self.end_[2])
end

---Performs a pre-order depth traversal of the test tree, calling the given function with each test.
---@param f fun(test: please.parsing.Test)
function Test:for_each(f)
  f(self)
  for _, child in ipairs(self.children) do
    child:for_each(f)
  end
end

---Wrapper around TSNode:iter_matches which returns the captures for each match.
---@param query vim.treesitter.Query
---@param node TSNode
---@param opts table|nil Options:
---   - max_start_depth (integer) if non-zero, sets the maximum start depth
---     for each match. This is used to prevent traversing too deep into a tree.
---     Requires treesitter >= 0.20.9.
---@return fun(): table<string, TSNode>?
local function iter_match_captures(query, node, opts)
  local iter = query:iter_matches(node, 0, nil, nil, opts)
  return function()
    local _, match = iter()
    if not match then
      return nil
    end
    local captures = {}
    for id, capture in pairs(match) do
      local name = query.captures[id]
      captures[name] = capture
    end
    return captures
  end
end

local queries = {
  go = {
    test_func = [[
      (function_declaration
        (identifier) @name
        (#match? @name "^Test.+")
        parameters: (parameter_list
          (parameter_declaration
            name: (identifier) @receiver
            type: (pointer_type) @_receiver_type)
            (#eq? @_receiver_type "*testing.T"))
        body: (block) @body) @test
    ]],
    test_suite_method = [[
      (method_declaration
        receiver: (parameter_list
          (parameter_declaration
            name: (identifier) @receiver
            type: [
              (pointer_type
                (type_identifier) @receiver_type)
              (type_identifier) @receiver_type
            ]))
        name: (field_identifier) @name
        (#match? @name "^Test.+")
        body: (block) @body) @test
    ]],
    test_suite = [[
      (function_declaration
        (identifier) @name
        (#match? @name "^Test.+")
        parameters: (parameter_list
          (parameter_declaration
            name: (identifier) @_t_param
            type: (pointer_type) @_t_param_type)
            (#eq? @_t_param_type "*testing.T"))
        body: (block
          (expression_statement
            (call_expression
              function: (selector_expression
                field: (field_identifier) @_run_field
                (#eq? @_run_field "Run"))
              arguments: (argument_list
                (identifier) @_run_t_arg
                (#eq? @_run_t_arg @_t_param)
                [
                  (unary_expression
                    operand: (composite_literal
                      type: (type_identifier) @suite_type))
                  (call_expression
                    function: (identifier) @_new_func
                    (#eq? @_new_func "new")
                    arguments: (argument_list
                      (type_identifier) @suite_type))
                ])))))
    ]],
    subtest = [[
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @receiver
            field: (field_identifier) @_run_field)
            (#eq? @_run_field "Run")
          arguments: (argument_list
            (interpreted_string_literal) @name
            (func_literal
              body: (block) @body)))) @subtest
    ]],
    table_test = [[
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
            (expression_statement
              (call_expression
                function: (selector_expression
                  operand: (identifier) @receiver
                  field: (field_identifier) @_run_field)
                (#eq? @_run_field "Run")
                arguments: (argument_list
                  (selector_expression
                    operand: (identifier) @_name_arg_operand
                    field: (field_identifier) @_name_arg_field)
                  (#eq? @_name_arg_operand @_test_cases_loop_var)
                  (#eq? @_name_arg_field @_test_case_struct_name_field)
                  (func_literal
                    body: (block))))))) @for_loop)
    ]],
  },
  python = {
    unittest_methods = [[
      (class_definition
        name: (identifier) @class_name
        body: (block [
          (function_definition
            name: (identifier) @name
            (#match? @name "^test_.+")) @test
          (decorated_definition
            definition: (function_definition
              name: (identifier) @name
              (#match? @name "^test_.+"))) @test
        ])) @class
    ]],
  },
}

local parse_go_subtests

---@param parent_name string
---@param parent_selector string
---@param receiver string
---@param parent_body TSNode
---@return please.parsing.Test[]
function parse_go_subtests(parent_name, parent_selector, receiver, parent_body)
  local subtests = {} ---@type please.parsing.Test[]

  local subtest_query = vim.treesitter.query.parse('go', queries.go.subtest)
  for captures in iter_match_captures(subtest_query, parent_body, { max_start_depth = 1 }) do
    local subtest_receiver = vim.treesitter.get_node_text(captures.receiver, 0)
    if subtest_receiver == receiver then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local subtest_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. subtest_name
      local selector = parent_selector .. '/^' .. subtest_name .. '$'
      local children = parse_go_subtests(name, selector, subtest_receiver, captures.body)
      table.insert(subtests, Test:new(name, selector, captures.subtest, children))
    end
  end

  local table_test_query = vim.treesitter.query.parse('go', queries.go.table_test)
  for captures in iter_match_captures(table_test_query, parent_body, { max_start_depth = 1 }) do
    local subtest_receiver = vim.treesitter.get_node_text(captures.receiver, 0)
    if subtest_receiver == receiver then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local test_case_name = vim.treesitter.get_node_text(captures.name, 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. test_case_name
      local selector = parent_selector .. '/^' .. test_case_name .. '$'
      table.insert(subtests, Test:new(name, selector, captures.test_case))
    end
  end

  return subtests
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_go_test_func(root_node)
  local test_func_query = vim.treesitter.query.parse('go', queries.go.test_func)
  for captures in iter_match_captures(test_func_query, root_node) do
    local name = vim.treesitter.get_node_text(captures.name, 0)
    local selector = '^' .. name .. '$'
    local receiver = vim.treesitter.get_node_text(captures.receiver, 0)
    local children = parse_go_subtests(name, selector, receiver, captures.body)
    return Test:new(name, selector, captures.test, children)
  end
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_go_test_suite_method(root_node)
  local test_suite_method_query = vim.treesitter.query.parse('go', queries.go.test_suite_method)
  for captures in iter_match_captures(test_suite_method_query, root_node) do
    local name = vim.treesitter.get_node_text(captures.name, 0)
    local selector = '/^' .. name .. '$'
    local receiver = vim.treesitter.get_node_text(captures.receiver, 0)
    local receiver_type = vim.treesitter.get_node_text(captures.receiver_type, 0)

    local tree = vim.treesitter.get_parser(0, vim.bo.filetype):parse()[1]
    local suite_names = {}
    local test_suite_query = vim.treesitter.query.parse('go', queries.go.test_suite)
    for test_suite_captures in iter_match_captures(test_suite_query, tree:root()) do
      if vim.treesitter.get_node_text(test_suite_captures.suite_type, 0) == receiver_type then
        table.insert(suite_names, vim.treesitter.get_node_text(test_suite_captures.name, 0))
      end
    end
    -- If there 0 suite names, then obviously we can't prefix the name and selector.
    -- If there are more than 1, then it's ambiguous which one we should use, so we also leave the name and selector so
    -- that both suites are included by the Go test runner.
    if #suite_names == 1 then
      local suite_name = suite_names[1]
      name = suite_name .. '/' .. name
      selector = '^' .. suite_name .. '$' .. selector
    end
    local children = parse_go_subtests(name, selector, receiver, captures.body)
    return Test:new(name, selector, captures.test, children)
  end
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_python_unittest_methods(root_node)
  local test ---@type please.parsing.Test
  local unittest_methods_query = vim.treesitter.query.parse('python', queries.python.unittest_methods)
  for captures in iter_match_captures(unittest_methods_query, root_node) do
    local class_name = vim.treesitter.get_node_text(captures.class_name, 0)
    if not test then
      test = Test:new(class_name, class_name, captures.class)
    end
    local name = class_name .. '.' .. vim.treesitter.get_node_text(captures.name, 0)
    table.insert(test.children, Test:new(name, name, captures.test))
  end
  return test
end

---@type table<string, table<string, fun(root_node:TSNode):please.parsing.Test?>>
local parsers_by_root_node_type_by_filetype = {
  go = {
    function_declaration = parse_go_test_func,
    method_declaration = parse_go_test_suite_method,
  },
  python = {
    class_definition = parse_python_unittest_methods,
  },
}

---Returns the test at the current cursor position.
---Current supported languages are:
---- Go
---  - test functions
---  - subtests
---  - table tests
---  - testify suite methods
---  - testify suite subtests
---  - testify suite table tests
---- Python
---  - unittest test classes
---  - unittest test methods
---@return {name:string, selector:string}?
---@return string? errmsg
function parsing.get_test_at_cursor()
  logging.log_call('please.parsing.get_test_at_cursor')

  local parsers_by_root_node_type = parsers_by_root_node_type_by_filetype[vim.bo.filetype]
  if not parsers_by_root_node_type then
    return nil, string.format('finding tests is not supported for %s files', vim.bo.filetype)
  end

  check_parser_installed(vim.bo.filetype)

  local root_node = vim.treesitter.get_node()
  while root_node and not parsers_by_root_node_type[root_node:type()] do
    root_node = root_node:parent()
  end
  if not root_node then
    return nil, 'cursor is not in a test'
  end

  local parser = parsers_by_root_node_type[root_node:type()]
  local parent_test = parser(root_node)
  if not parent_test then
    return nil, 'cursor is not in a test'
  end

  local test ---@type please.parsing.Test
  local current_pos = vim.api.nvim_win_get_cursor(0)
  parent_test:for_each(function(t)
    if t:contains(current_pos) then
      test = t
    end
  end)

  return { name = test.name, selector = test.selector }
end

local function build_label(root, build_file, target)
  local dir = vim.fs.dirname(build_file)
  local normalized_root = vim.fs.normalize(root)
  local normalized_dir = vim.fs.normalize(dir)
  local pkg = normalized_dir:gsub('^' .. vim.pesc(normalized_root) .. '/?', '')
  return string.format('//%s:%s', pkg, target)
end

---Returns the label and rule of the build target under the cursor.
---@param root string: an absolute path to the repo root
---@return string?: a build label
---@return string?: a build rule
---@return string? errmsg
-- TODO: return a table instead of multiple values
function parsing.get_target_at_cursor(root)
  logging.log_call('parsing.get_target_at_cursor')

  check_parser_installed('please')

  local tree = vim.treesitter.get_parser(0, 'python'):parse()[1]
  local query = vim.treesitter.query.parse('python', make_build_target_query())

  for _, match in query:iter_matches(tree:root(), 0, nil, nil) do
    local captures = extract_captures_from_match(match, query)
    if cursor_in_node_range(captures.target) then
      local name = vim.treesitter.get_node_text(captures.name, 0)
      -- name returned by treesitter is surrounded by quotes
      if name:sub(1, 1) == '"' then
        name = name:match('^"(.+)"$')
      else
        name = name:match("^'(.+)'$")
      end
      local rule = vim.treesitter.get_node_text(captures.rule, 0)
      local build_file = vim.api.nvim_buf_get_name(0)
      return build_label(root, build_file, name), rule, nil
    end
  end

  return nil, nil, 'cursor is not in a build target definition'
end

return parsing
