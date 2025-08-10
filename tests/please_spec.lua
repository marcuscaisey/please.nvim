local stub = require('luassert.stub')
local please = require('please')
local Runner = require('please.Runner')
local temptree = require('tests.temptree')

-- require('please.logging').toggle_debug()

-- When this test file is run multiple times in parallel (in a non-sandboxed environment), at least one of the runs
-- usually fails because some functionality being tested relies on use of the clipboard which is being shared between
-- all of the runs. We override the default clipboard provider so that each run uses its own in memory clipboard instead
-- of the system one.
local clipboard_lines
vim.g.clipboard = {
  name = 'fake',
  copy = {
    ['*'] = function(lines)
      clipboard_lines = lines
    end,
    ['+'] = function(lines)
      clipboard_lines = lines
    end,
  },
  paste = {
    ['*'] = function()
      return clipboard_lines
    end,
    ['+'] = function()
      return clipboard_lines
    end,
  },
}

RunnerSpy = {}
RunnerSpy.__index = RunnerSpy

function RunnerSpy:new()
  local o = {
    _root = nil,
    _args = nil,
    _called = false,
    _started = false,
  }
  stub(Runner, 'new', function(_, root, args)
    o._root = root
    o._args = args
    o._called = true
    return o
  end)
  return setmetatable(o, self)
end

function RunnerSpy:start()
  self._started = true
end

function RunnerSpy:stop() end

function RunnerSpy:minimise() end

function RunnerSpy:assert_called_with(root, args)
  assert.is_true(self._called, 'Runner:new has not been called')
  assert.equal(root, self._root, 'incorrect root passed to Runner:new')
  assert.same(args, self._args, 'incorrect args passed to Runner:new')
end

function RunnerSpy:assert_started()
  assert.is_true(self._started, 'Runner:start has not been called')
end

SelectFake = {}
SelectFake.__index = SelectFake

function SelectFake:new()
  local o = {
    _called = false,
    _items = nil,
    _formatted_items = nil,
    _opts = nil,
    _on_choice = nil,
  }
  stub(vim.ui, 'select', function(items, opts, on_choice)
    o._items = items
    o._opts = opts
    o._on_choice = on_choice
    o._formatted_items = vim.tbl_map(opts.format_item or tostring, items)
    o._called = true
  end)
  return setmetatable(o, self)
end

function SelectFake:assert_items(items)
  self:assert_called()
  assert.same(items, self._formatted_items, 'incorrect items passed to vim.ui.select')
end

function SelectFake:assert_prompt(prompt)
  self:assert_called()
  assert.is_not_nil(self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
  assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
end

function SelectFake:choose_item(item)
  self:assert_called()
  assert.is_true(
    vim.tbl_contains(self._formatted_items, item),
    string.format(
      'cannot choose item "%s" which was not passed to vim.ui.select, available choices are: %s',
      item,
      vim.inspect(self._formatted_items)
    )
  )
  for i, v in ipairs(self._formatted_items) do
    if v == item then
      self._on_choice(self._items[i], i)
    end
  end
end

function SelectFake:assert_called()
  assert.is_true(self._called, 'vim.ui.select has not been called')
end

function SelectFake:assert_not_called()
  assert.is_false(self._called, 'vim.ui.select has been called')
end

InputFake = {}
InputFake.__index = InputFake

function InputFake:new()
  local o = {
    _called = false,
    _opts = nil,
    _on_confirm = nil,
  }
  stub(vim.ui, 'input', function(opts, on_confirm)
    o._opts = opts
    o._on_confirm = on_confirm
    o._called = true
  end)
  return setmetatable(o, self)
end

function InputFake:assert_prompt(prompt)
  self:assert_called()
  assert.is_not_nil(self._opts.prompt, 'expected prompt opt passed to vim.ui.input')
  assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.input')
end

function InputFake:enter_input(input)
  self:assert_called()
  self._on_confirm(input)
end

function InputFake:assert_called()
  assert.is_true(self._called, 'vim.ui.input has not been called')
end

describe('build', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        filegroup(
            name = "foo1_and_foo2",
            srcs = [
                "foo1.txt",
                "foo2.txt",
            ],
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    })
  end

  describe('in source file', function()
    it('should build target which uses file as input', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call build
      please.build()
      -- THEN the target which the file is an input for is built
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.build()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz build //:foo1_and_foo2' })
      -- WHEN we select the build command
      select_fake:choose_item('plz build //:foo1_and_foo2')
      -- THEN the target is built again
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)

    it('should prompt user to choose which target to build if there is more than one', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call build
      please.build()
      -- THEN we're prompted to choose which target to build
      select_fake:assert_prompt('Select target to build')
      select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the targets
      select_fake:choose_item('//:foo1_and_foo2')
      -- THEN the target is built
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)
  end)

  describe('in BUILD file', function()
    it('should build target under cursor', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- inside definition of :foo1_and_foo2
      -- WHEN we call build
      please.build()
      -- THEN the target under the cursor is built
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- inside definition of :foo1_and_foo2
      please.build()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz build //:foo1_and_foo2' })
      -- WHEN we select the build command
      select_fake:choose_item('plz build //:foo1_and_foo2')
      -- THEN the target is built again
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)
  end)
end)

describe('run', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        filegroup(
            name = "foo1_and_foo2",
            srcs = [
                "foo1.txt",
                "foo2.txt",
            ],
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    })
  end

  describe('in source file', function()
    it('should run target which uses file as input', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to enter arguments for the program
      input_fake:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      input_fake:enter_input('--foo foo --bar bar')
      -- THEN the target which the file is an input for is run with those arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()
      local select_fake = SelectFake:new()

      -- GIVEN that we've run a build target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.run()
      input_fake:enter_input('--foo foo --bar bar')
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz run //:foo1_and_foo2 -- --foo foo --bar bar' })
      -- WHEN we select the run command
      select_fake:choose_item('plz run //:foo1_and_foo2 -- --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
    end)

    it('should prompt user to choose which target to run if there is more than one', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()
      local input_fake = InputFake:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to choose which target to run
      select_fake:assert_prompt('Select target to run')
      select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the targets
      select_fake:choose_item('//:foo1_and_foo2')
      -- THEN we're prompted to enter arguments for the program
      input_fake:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      input_fake:enter_input('--foo foo --bar bar')
      -- THEN the target is run with those arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
    end)
  end)

  describe('in BUILD file', function()
    it('should run target under cursor', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to enter arguments for the program
      input_fake:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      input_fake:enter_input('--foo foo --bar bar')
      -- THEN the target is run with those arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've run a build target
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
      please.run()
      input_fake:enter_input('--foo foo --bar bar')
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz run //:foo1 -- --foo foo --bar bar' })
      -- WHEN we select the run command
      select_fake:choose_item('plz run //:foo1 -- --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })
    end)
  end)

  it('should not include program args in command history entry when none are passed as input', function()
    local root = create_temp_tree()
    local input_fake = InputFake:new()
    local select_fake = SelectFake:new()

    -- GIVEN we've run a build target and passed no arguments
    vim.cmd('edit ' .. root .. '/BUILD')
    vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
    please.run()
    input_fake:enter_input('')
    -- WHEN we call history
    please.history()
    -- THEN the command history entry should not include the empty program args
    select_fake:assert_prompt('Pick command to run again')
    select_fake:assert_items({ 'plz run //:foo1' })
  end)
end)

describe('test', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      ['foo/'] = {
        BUILD = [[
          go_test(
              name = "foo1_test",
              srcs = ["foo1_test.go"],
              external = True,
          )

          go_test(
              name = "foo1_and_foo2_test",
              srcs = [
                  "foo1_test.go",
                  "foo2_test.go",
              ],
              external = True,
          )
        ]],
        ['foo1_test.go'] = [[
          package foo_test

          import "testing"

          func TestPasses(t *testing.T) {
          }

          func TestFails(t *testing.T) {
              t.Fatal("oh no")
          }
        ]],
        ['foo2_test.go'] = [[
          package foo_test

          import "testing"

          func TestPasses(t *testing.T) {
          }

          func TestFails(t *testing.T) {
              t.Fatal("oh no")
          }
        ]],
      },
    })
  end

  describe('in source file', function()
    it('should test target which uses file as input', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      -- WHEN we call test
      please.test()
      -- THEN the target which the file is an input for is tested
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've tested a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      please.test()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz test //foo:foo1_and_foo2_test' })
      -- WHEN we select the test command
      select_fake:choose_item('plz test //foo:foo1_and_foo2_test')
      -- THEN the target is tested again
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
    end)

    it('should prompt user to choose which target to test if there is more than one', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
      -- WHEN we call test
      please.test()
      -- THEN we're prompted to choose which target to test
      select_fake:assert_prompt('Select target to test')
      select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
      -- WHEN we select one of the targets
      select_fake:choose_item('//foo:foo1_and_foo2_test')
      -- THEN the test is run
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
    end)

    describe('with under_cursor=true', function()
      it('should run test under the cursor', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()

        -- GIVEN we're editing a test file and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        -- WHEN we call test with under_cursor=true
        please.test({ under_cursor = true })
        -- THEN the test under the cursor is tested
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })
      end)

      it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've tested the function under the cursor
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        please.test({ under_cursor = true })
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again')
        select_fake:assert_items({ 'plz test //foo:foo1_and_foo2_test ^TestFails$' })
        -- WHEN we select the test command
        select_fake:choose_item('plz test //foo:foo1_and_foo2_test ^TestFails$')
        -- THEN the test is run again
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })
      end)

      it('should prompt user to choose which target to test if there is more than one', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we're editing a test file referenced by multiple build targets and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        -- WHEN we call test with under_cursor=true
        please.test({ under_cursor = true })
        -- THEN we're prompted to choose which target to test
        select_fake:assert_prompt('Select target to test')
        select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
        -- WHEN we select one of the targets
        select_fake:choose_item('//foo:foo1_and_foo2_test')
        -- THEN the test is run
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })
      end)
    end)
  end)

  describe('in BUILD file', function()
    it('should test target under cursor', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      -- WHEN we call test
      please.test()
      -- THEN the target is tested
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_test' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've tested a build target
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      please.test()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz test //foo:foo1_test' })
      -- WHEN we select the test command
      select_fake:choose_item('plz test //foo:foo1_test')
      -- THEN the target is tested again
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_test' })
    end)
  end)
end)

describe('debug', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      ['foo/'] = {
        BUILD = [[
          go_test(
              name = "foo1_test",
              srcs = ["foo1_test.go"],
              external = True,
          )

          go_test(
              name = "foo1_and_foo2_test",
              srcs = [
                  "foo1_test.go",
                  "foo2_test.go",
              ],
              external = True,
          )
        ]],
        ['foo1_test.go'] = [[
          package foo_test

          import "testing"

          func TestPasses(t *testing.T) {
          }

          func TestFails(t *testing.T) {
              t.Fatal("oh no")
          }
        ]],
        ['foo2_test.go'] = [[
          package foo_test

          import "testing"

          func TestPasses(t *testing.T) {
          }

          func TestFails(t *testing.T) {
              t.Fatal("oh no")
          }
        ]],
      },
    })
  end

  describe('in source file', function()
    it('should build target which uses file as input with dbg config', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      -- WHEN we call debug
      please.debug()
      -- THEN the target which the file is an input for is built with dbg config
      runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've debugged a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      please.debug()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz debug //foo:foo1_and_foo2_test' })
      -- WHEN we select the debug command
      select_fake:choose_item('plz debug //foo:foo1_and_foo2_test')
      -- THEN the target is built again with dbg config
      runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
    end)

    it('should prompt user to choose which target to debug if there is more than one', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
      -- WHEN we call debug
      please.debug()
      -- THEN we're prompted to choose which target to debug
      select_fake:assert_prompt('Select target to debug')
      select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
      -- WHEN we select one of the targets
      select_fake:choose_item('//foo:foo1_and_foo2_test')
      -- THEN the target is built with dbg config
      runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
    end)

    describe('with under_cursor=true', function()
      it('should build target which uses file as input with dbg config', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()

        -- GIVEN we're editing a test file and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        -- WHEN we call debug with under_cursor=true
        please.debug({ under_cursor = true })
        -- THEN the test target is built with dbg config
        runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
      end)

      it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've debugged the function under the cursor
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        please.debug({ under_cursor = true })
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again')
        select_fake:assert_items({ 'plz debug //foo:foo1_and_foo2_test ^TestFails$' })
        -- WHEN we select the debug command
        select_fake:choose_item('plz debug //foo:foo1_and_foo2_test ^TestFails$')
        -- THEN the test target is built with dbg config
        runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
      end)

      it('should prompt user to choose which target to debug if there is more than one', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we're editing a test file referenced by multiple build targets and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        -- WHEN we call debug with under_cursor=true
        please.debug({ under_cursor = true })
        -- THEN we're prompted to choose which target to debug
        select_fake:assert_prompt('Select target to debug')
        select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
        -- WHEN we select one of the targets
        select_fake:choose_item('//foo:foo1_and_foo2_test')
        -- THEN the target is built again with dbg config
        runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
      end)
    end)
  end)

  describe('in BUILD file', function()
    it('should build target under cursor with dbg config', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      -- WHEN we call debug
      please.debug()
      -- THEN the target is built with dbg config
      runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_test' })
    end)

    it('should add entry to command history', function()
      local root = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've debugged a build target
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      please.debug()
      -- WHEN we call history
      please.history()
      -- THEN we're prompted to pick a command to run again
      select_fake:assert_prompt('Pick command to run again')
      select_fake:assert_items({ 'plz debug //foo:foo1_test' })
      -- WHEN we select the debug command
      select_fake:choose_item('plz debug //foo:foo1_test')
      -- THEN the target is built with dbg config
      runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_test' })
    end)
  end)
end)

describe('command', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )
      ]],
      ['foo.txt'] = 'foo content',
    })
  end

  it('should call plz with the provided arguments', function()
    local root = create_temp_tree()
    local runner_spy = RunnerSpy:new()

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')
    -- WHEN we call command with some arguments
    please.command('build', '//:foo')
    -- THEN plz is called with those arguments
    runner_spy:assert_called_with(root, { 'build', '//:foo' })
  end)

  it('should add entry to command history', function()
    local root = create_temp_tree()
    local runner_spy = RunnerSpy:new()
    local select_fake = SelectFake:new()

    -- GIVEN we've run a command
    vim.cmd('edit ' .. root .. '/foo.txt')
    please.command('build', '//:foo')
    -- WHEN we call history
    please.history()
    -- THEN we're prompted to pick a command to run again
    select_fake:assert_prompt('Pick command to run again')
    select_fake:assert_items({ 'plz build //:foo' })
    -- WHEN we select the command
    select_fake:choose_item('plz build //:foo')
    -- THEN the command is run again
    runner_spy:assert_called_with(root, { 'build', '//:foo' })
  end)
end)

describe('history', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        export_file(
            name = "foo2",
            src = "foo2.txt",
        )

        export_file(
            name = "foo3",
            src = "foo3.txt",
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
      ['foo3.txt'] = 'foo3 content',
    })
  end

  it('should order items from most to least recent', function()
    local root = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've built three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.build()
    end
    -- WHEN we call history
    please.history()
    -- THEN the commands to build each label are ordered from most to least recent
    select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2', 'plz build //:foo1' })
  end)

  it('should move rerun command to the top of history', function()
    local root = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've built three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.build()
    end
    -- WHEN we call history
    please.history()
    -- AND rerun the second command
    select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2', 'plz build //:foo1' })
    select_fake:choose_item('plz build //:foo2')
    -- THEN it has been moved to the top of the history
    please.history()
    select_fake:assert_items({ 'plz build //:foo2', 'plz build //:foo3', 'plz build //:foo1' })
  end)

  it('should display the n most recent items', function()
    local root = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've built three targets, one after the other
    please.setup({ max_history_items = 2 })
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.build()
    end
    please.setup({ max_history_items = 20 })
    -- WHEN we call history
    please.history()
    -- THEN the commands to build the two most recently built target are ordered from most to least recent
    select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2' })

    please.setup({ max_history_items = 20 })
  end)
end)

describe('clear_history', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        export_file(
            name = "foo2",
            src = "foo2.txt",
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    })
  end

  it('should delete all stored commands', function()
    local root = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've built a target
    vim.cmd('edit ' .. root .. '/' .. 'foo1.txt')
    please.build()
    -- WHEN we call clear_history
    please.clear_history()
    -- THEN history does not prompt for a command to run again because the stored commands have been deleted
    please.history()
    select_fake:assert_not_called()
    -- WHEN we build another target
    vim.cmd('edit ' .. root .. '/' .. 'foo2.txt')
    please.build()
    -- WHEN we call history
    please.history()
    -- THEN the command to build the new target is the only one displayed
    select_fake:assert_items({ 'plz build //:foo2' })
  end)
end)

describe('jump_to_target', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        filegroup(
            name = "foo1_and_foo2",
            srcs = [
                "foo1.txt",
                "foo2.txt",
            ],
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    })
  end

  it('should jump from file to build target which uses it as an input', function()
    local root = create_temp_tree()

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo2.txt')
    -- WHEN we call jump_to_target
    please.jump_to_target()
    -- THEN the BUILD file containing the build target for the file is opened
    assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
  end)

  it('should prompt user to choose which target to jump to if there is more than one', function()
    local root = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we're editing a file referenced by multiple BUILD targets
    vim.cmd('edit ' .. root .. '/foo1.txt')
    -- WHEN we call jump_to_target
    please.jump_to_target()
    -- THEN we're prompted to choose which target to jump to
    select_fake:assert_prompt('Select target to jump to')
    select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
    -- WHEN we select one of the targets
    select_fake:choose_item('//:foo1_and_foo2')
    -- THEN the BUILD file containing the chosen build target is opened
    assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
  end)
end)

describe('yank', function()
  local function create_temp_tree()
    return temptree.create({
      '.plzconfig',
      BUILD = [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        filegroup(
            name = "foo1_and_foo2",
            srcs = [
                "foo1.txt",
                "foo2.txt",
            ],
        )
      ]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    })
  end

  describe('in source file', function()
    it('should yank label of target which uses file as input', function()
      local root = create_temp_tree()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call yank
      please.yank()
      -- THEN the label of the target which the file is an input for is yanked into the " and * registers
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')
    end)

    it("should prompt user to choose which target's label to yank if there is more than one", function()
      local root = create_temp_tree()
      local select_fake = SelectFake:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call yank
      please.yank()
      -- THEN we're prompted to choose which label to yank
      select_fake:assert_prompt('Select label to yank')
      select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the labels
      select_fake:choose_item('//:foo1_and_foo2')
      -- THEN the label is yanked into the " and * registers
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')
    end)
  end)

  describe('in BUILD file', function()
    it('should yank target under cursor', function()
      local root = create_temp_tree()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1
      -- WHEN we call yank
      please.yank()
      -- THEN the target's label is yanked into the " and * register
      local unnamed = vim.fn.getreg('"')
      local star = vim.fn.getreg('*')
      assert.equal('//:foo1', unnamed, 'incorrect value in " register')
      assert.equal('//:foo1', star, 'incorrect value in * register')
    end)
  end)
end)
