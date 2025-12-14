local logging = require('please.logging')

vim.treesitter.language.register('python', 'please')

local M = {}

local build_file_names = { 'BUILD', 'BUILD.plz' }

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

---Wrapper around Query:iter_matches which returns the captures for each match.
---@param query vim.treesitter.Query
---@param bufnr integer
---@param node TSNode
---@param opts? table Optional keyword arguments:
---   - max_start_depth (integer) if non-zero, sets the maximum start depth
---     for each match. This is used to prevent traversing too deep into a tree.
---   - match_limit (integer) Set the maximum number of in-progress matches (Default: 256).
---@return fun(): table<string, TSNode[]>?
local function iter_match_captures(query, bufnr, node, opts)
  opts = opts or {}
  opts.all = true
  local iter = query:iter_matches(node, bufnr, nil, nil, opts)
  return function()
    local _, match = iter()
    if not match then
      return nil
    end
    local captures = {}
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      captures[name] = nodes
    end
    return captures
  end
end

local function iter_build_target_match_captures(bufnr)
  local query = vim.treesitter.query.parse(
    'python',
    [[
      (call
        function: (identifier) @rule
        arguments: (argument_list
          (keyword_argument
            name: (
              (identifier) @kwarg
              (#eq? @kwarg "name"))
            value: (
              (string) @name)))) @target
    ]]
  )
  local tree = vim.treesitter.get_parser(bufnr, 'python'):parse()[1]
  return iter_match_captures(query, bufnr, tree:root())
end

local function ts_range_to_nvim_range(ts_start_row, ts_start_col)
  -- treesitter ranges are (0, 0)-based
  -- nvim ranges are (1, 0)-based
  return { ts_start_row + 1, ts_start_col }
end

---Returns the BUILD file containing a target and its (1, 0)-based position in that file.
---If the location of the target in the BUILD file can't be found (it might be dynamically created), then position will
---be {1, 0}.
---@param root string an absolute path to the repo root
---@param label string: a build label of the form //path/to/pkg:target or //path/to/pkg
---@return {file: string, position: [number, number]}?
---@return string? errmsg
function M.locate_build_target(root, label)
  logging.log_call('parsing.locate_build_target')

  check_parser_installed('please')

  local pkg, name = label:match('^//([^:]*):([^/]+)$')
  if not pkg then
    pkg = label:match('^//([^:]+)$')
    if pkg then
      name = vim.fs.basename(pkg)
    end
  end
  if not pkg then
    return nil, string.format('"%s" is not a valid label', label)
  end
  local pkg_path = vim.fs.joinpath(root, pkg)
  for _, build_file_name in ipairs(build_file_names) do
    local build_path = vim.fs.joinpath(pkg_path, build_file_name)
    local stat = vim.uv.fs_stat(build_path)
    if stat and stat.type == 'file' then
      local filepath = vim.fs.normalize(build_path)

      local bufnr = vim.fn.bufnr(filepath, true) -- this creates the buffer as unlisted if it doesn't exist
      vim.fn.bufload(bufnr)
      for captures in iter_build_target_match_captures(bufnr) do
        if vim.treesitter.get_node_text(captures.name[1], bufnr):sub(2, -2) == name then -- remove the quotes
          local ts_start_row, ts_start_col = captures.target[1]:range()
          return { file = filepath, position = ts_range_to_nvim_range(ts_start_row, ts_start_col) }
        end
      end

      return { file = filepath, position = { 1, 0 } }
    end
  end

  return nil, string.format('no build file exists for package "%s"', pkg)
end

local function cursor_in_node_range(node)
  local pos = vim.api.nvim_win_get_cursor(0)
  return vim.treesitter.is_in_node_range(node, pos[1] - 1, pos[2])
end

local function build_label(root, build_file, target)
  local dir = vim.fs.dirname(build_file)
  local normalized_root = vim.fs.normalize(root)
  local normalized_dir = vim.fs.normalize(dir)
  local pkg = normalized_dir:gsub('^' .. vim.pesc(normalized_root) .. '/?', '')
  if target == vim.fs.basename(pkg) then
    return '//' .. pkg
  else
    return string.format('//%s:%s', pkg, target)
  end
end

---Returns the label and rule of the build target under the cursor.
---@param root string: an absolute path to the repo root
---@return {label: string, rule: string}?
---@return string? errmsg
function M.get_target_at_cursor(root)
  logging.log_call('parsing.get_target_at_cursor')

  check_parser_installed('please')

  for captures in iter_build_target_match_captures(0) do
    if cursor_in_node_range(captures.target[1]) then
      local name = vim.treesitter.get_node_text(captures.name[1], 0):sub(2, -2) -- remove the quotes
      local rule = vim.treesitter.get_node_text(captures.rule[1], 0)
      local build_file = vim.api.nvim_buf_get_name(0)
      return { label = build_label(root, build_file, name), rule = rule }
    end
  end

  return nil, 'cursor is not in a build target definition'
end

---Returns the build label at the cursor if there is one, otherwise nil.
---@return string?
function M.get_label_at_cursor()
  logging.log_call('parsing.get_label_at_cursor')
  local line = vim.fn.line('.') -- 1-based
  local col = vim.fn.col('.') -- 1-based
  local regex = vim.regex(
    [[//\%(\%(\%(\%(\w\|-\)\+\%(/\%(\w\|-\)\+\)*\)*:\%(\w\|-\|#\)\+\)\|\%(\%(\w\|-\)\+\%(/\%(\w\|-\)\+\)*\)\)]]
  )
  local start = 0
  while true do
    local match_start_rel, match_end_rel = regex:match_line(0, line - 1, start) -- 0-based
    if not match_start_rel or not match_end_rel then
      return nil
    end
    local match_start_abs = start + match_start_rel
    local match_end_abs = start + match_end_rel
    if match_start_abs + 1 <= col and col < match_end_abs + 1 then
      return string.sub(vim.api.nvim_get_current_line(), match_start_abs + 1, match_end_abs)
    end
    start = match_end_abs
  end
end

---Language agnostic representation of a test and its children. A Test along with its children forms a tree of Tests.
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

local parse_go_subtests

---@param parent_name string
---@param parent_selector string
---@param receiver string
---@param parent_body TSNode
---@return please.parsing.Test[]
function parse_go_subtests(parent_name, parent_selector, receiver, parent_body)
  local subtests = {} ---@type please.parsing.Test[]

  local subtest_query = vim.treesitter.query.parse(
    'go',
    [[
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
    ]]
  )
  for captures in iter_match_captures(subtest_query, 0, parent_body, { max_start_depth = 1 }) do
    local subtest_receiver = vim.treesitter.get_node_text(captures.receiver[1], 0)
    if subtest_receiver == receiver then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local subtest_name = vim.treesitter.get_node_text(captures.name[1], 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. subtest_name
      local selector = parent_selector .. '/^' .. subtest_name .. '$'
      local children = parse_go_subtests(name, selector, subtest_receiver, captures.body[1])
      table.insert(subtests, Test:new(name, selector, captures.subtest[1], children))
    end
  end

  local table_test_query = vim.treesitter.query.parse(
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
    ]]
  )
  for captures in iter_match_captures(table_test_query, 0, parent_body, { max_start_depth = 1 }) do
    local subtest_receiver = vim.treesitter.get_node_text(captures.receiver[1], 0)
    if subtest_receiver == receiver then
      -- The subtest's name will be surrounded with " since it's a string. We also have to replace the spaces with
      -- underscores to match how the Go test runner displays test names.
      local test_case_name = vim.treesitter.get_node_text(captures.name[1], 0):match('"(.+)"'):gsub(' ', '_')
      local name = parent_name .. '/' .. test_case_name
      local selector = parent_selector .. '/^' .. test_case_name .. '$'
      table.insert(subtests, Test:new(name, selector, captures.test_case[1]))
    end
  end

  return subtests
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_go_test_func(root_node)
  local query = vim.treesitter.query.parse(
    'go',
    [[
      (function_declaration
        (identifier) @name
        (#match? @name "^Test.+")
        parameters: (parameter_list
          (parameter_declaration
            name: (identifier) @receiver
            type: (pointer_type) @_receiver_type)
            (#eq? @_receiver_type "*testing.T"))
        body: (block) @body) @test
    ]]
  )
  for captures in iter_match_captures(query, 0, root_node) do
    local name = vim.treesitter.get_node_text(captures.name[1], 0)
    local selector = '^' .. name .. '$'
    local receiver = vim.treesitter.get_node_text(captures.receiver[1], 0)
    local children = parse_go_subtests(name, selector, receiver, captures.body[1])
    return Test:new(name, selector, captures.test[1], children)
  end
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_go_test_suite_method(root_node)
  local test_suite_method_query = vim.treesitter.query.parse(
    'go',
    [[
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
    ]]
  )
  local test_suite_query = vim.treesitter.query.parse(
    'go',
    [[
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
    ]]
  )
  for captures in iter_match_captures(test_suite_method_query, 0, root_node) do
    local name = vim.treesitter.get_node_text(captures.name[1], 0)
    local selector = '/^' .. name .. '$'
    local receiver = vim.treesitter.get_node_text(captures.receiver[1], 0)
    local receiver_type = vim.treesitter.get_node_text(captures.receiver_type[1], 0)

    local tree = vim.treesitter.get_parser(0, vim.bo.filetype):parse()[1]
    local suite_names = {}
    for test_suite_captures in iter_match_captures(test_suite_query, 0, tree:root()) do
      if vim.treesitter.get_node_text(test_suite_captures.suite_type[1], 0) == receiver_type then
        table.insert(suite_names, vim.treesitter.get_node_text(test_suite_captures.name[1], 0))
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
    local children = parse_go_subtests(name, selector, receiver, captures.body[1])
    return Test:new(name, selector, captures.test[1], children)
  end
end

---@param root_node TSNode
---@return please.parsing.Test?
local function parse_python_unittest_methods(root_node)
  local test ---@type please.parsing.Test
  local unittest_methods_query = vim.treesitter.query.parse(
    'python',
    [[
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
    ]]
  )
  for captures in iter_match_captures(unittest_methods_query, 0, root_node) do
    local class_name = vim.treesitter.get_node_text(captures.class_name[1], 0)
    if not test then
      test = Test:new(class_name, class_name, captures.class[1])
    end
    local name = class_name .. '.' .. vim.treesitter.get_node_text(captures.name[1], 0)
    table.insert(test.children, Test:new(name, name, captures.test[1]))
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
---- Go - test functions, subtests, table tests, testify suite methods, testify suite subtests, testify suite table
---       tests
---- Python - unittest test classes, unittest test methods
---@return {name:string, selector:string}?
---@return string? errmsg
function M.get_test_at_cursor()
  logging.log_call('please.parsing.get_test_at_cursor')

  local parsers_by_root_node_type = parsers_by_root_node_type_by_filetype[vim.bo.filetype]
  if not parsers_by_root_node_type then
    return nil, string.format('finding tests is not supported for %s files', vim.bo.filetype)
  end

  check_parser_installed(vim.bo.filetype)
  vim.treesitter.get_parser():parse() -- Calling get_node on an unparsed tree can yield an invalid node.
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

return M
