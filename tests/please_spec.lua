local stub = require('luassert.stub')
local please = require('please')
local Runner = require('please.Runner')
local temptree = require('tests.utils.temptree')

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

function RunnerSpy:assert_called_with(root, args)
  if not self._called then
    error('Runner:new has not been called')
  end
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
  assert.not_nil(self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
  assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
end

function SelectFake:choose_item(item)
  self:assert_called()
  if not vim.tbl_contains(self._formatted_items, item) then
    error(
      string.format(
        'cannot choose item "%s" which was not passed to vim.ui.select, available choices are: %s',
        item,
        vim.inspect(self._formatted_items)
      )
    )
  end
  for i, v in ipairs(self._formatted_items) do
    if v == item then
      self._on_choice(self._items[i], i)
    end
  end
end

function SelectFake:assert_called()
  assert.is_true(self._called, 'vim.ui.select has not been called')
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
  assert.not_nil(self._opts.prompt, 'expected prompt opt passed to vim.ui.input')
  assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.input')
end

function InputFake:enter_input(input)
  self:assert_called()
  self._on_confirm(input)
end

function InputFake:assert_called()
  assert.is_true(self._called, 'vim.ui.input has not been called')
end

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
    local root, teardown_tree = create_temp_tree()

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo2.txt')
    -- WHEN we call jump_to_target
    please.jump_to_target()
    -- THEN the BUILD file containing the build target for the file is opened
    assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')

    teardown_tree()
  end)

  it('should add entry to action history', function()
    local root, teardown_tree = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've jumped to a target
    vim.cmd('edit ' .. root .. '/foo2.txt')
    please.jump_to_target()
    -- AND we edit a different file
    vim.cmd('edit ' .. root .. '/foo1.txt')
    -- WHEN we call action_history
    please.action_history()
    -- THEN we're prompted to pick an action to run again
    select_fake:assert_prompt('Pick action to run again')
    select_fake:assert_items({ 'Jump to //:foo1_and_foo2' })
    -- WHEN we select the jump action
    select_fake:choose_item('Jump to //:foo1_and_foo2')
    -- THEN the BUILD file is opened again
    assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target again
    assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')

    teardown_tree()
  end)

  it('should prompt user to choose which target to jump to if there is more than one', function()
    local root, teardown_tree = create_temp_tree()
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

    teardown_tree()
  end)
end)

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
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call build
      please.build()
      -- THEN the target which the file is an input for is built
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.build()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Build //:foo1_and_foo2' })
      -- WHEN we select the build action
      select_fake:choose_item('Build //:foo1_and_foo2')
      -- THEN the target is built again
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to build if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should build target under cursor', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- inside definition of :foo1_and_foo2
      -- WHEN we call build
      please.build()
      -- THEN the target under the cursor is built
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- inside definition of :foo1_and_foo2
      please.build()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Build //:foo1_and_foo2' })
      -- WHEN we select the build action
      select_fake:choose_item('Build //:foo1_and_foo2')
      -- THEN the target is built again
      runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)
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
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      -- WHEN we call test
      please.test()
      -- THEN the target which the file is an input for is tested
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've tested a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      please.test()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Test //foo:foo1_and_foo2_test' })
      -- WHEN we select the test action
      select_fake:choose_item('Test //foo:foo1_and_foo2_test')
      -- THEN the target is tested again
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to test if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)

    describe('with under_cursor=true', function()
      it('should run test under the cursor', function()
        local root, teardown_tree = create_temp_tree()
        local runner_spy = RunnerSpy:new()

        -- GIVEN we're editing a test file and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        -- WHEN we call test with under_cursor=true
        please.test({ under_cursor = true })
        -- THEN the test under the cursor is tested
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should add entry to action history', function()
        local root, teardown_tree = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've tested the function under the cursor
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
        please.test({ under_cursor = true })
        -- WHEN we call action_history
        please.action_history()
        -- THEN we're prompted to pick an action to run again
        select_fake:assert_prompt('Pick action to run again')
        select_fake:assert_items({ 'Test //foo:foo1_and_foo2_test TestFails' })
        -- WHEN we select the test action
        select_fake:choose_item('Test //foo:foo1_and_foo2_test TestFails')
        -- THEN the test is run again
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should prompt user to choose which target to test if there is more than one', function()
        local root, teardown_tree = create_temp_tree()
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

        teardown_tree()
      end)
    end)
  end)

  describe('in BUILD file', function()
    it('should test target under cursor', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      -- WHEN we call test
      please.test()
      -- THEN the target is tested
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_test' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've tested a build target
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
      please.test()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Test //foo:foo1_test' })
      -- WHEN we select the test action
      select_fake:choose_item('Test //foo:foo1_test')
      -- THEN the target is tested again
      runner_spy:assert_called_with(root, { 'test', '//foo:foo1_test' })

      teardown_tree()
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
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()
      local select_fake = SelectFake:new()

      -- GIVEN that we've run a build target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.run()
      input_fake:enter_input('--foo foo --bar bar')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Run //:foo1_and_foo2 --foo foo --bar bar' })
      -- WHEN we select the run action
      select_fake:choose_item('Run //:foo1_and_foo2 --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to run if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should run target under cursor', function()
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local runner_spy = RunnerSpy:new()
      local input_fake = InputFake:new()
      local select_fake = SelectFake:new()

      -- GIVEN we've run a build target
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
      please.run()
      input_fake:enter_input('--foo foo --bar bar')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Run //:foo1 --foo foo --bar bar' })
      -- WHEN we select the run action
      select_fake:choose_item('Run //:foo1 --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      runner_spy:assert_called_with(root, { 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)
  end)

  it('should not include program args in action history entry when none are passed as input', function()
    local root, teardown_tree = create_temp_tree()
    local input_fake = InputFake:new()
    local select_fake = SelectFake:new()

    -- GIVEN we've run a build target and passed no arguments
    vim.cmd('edit ' .. root .. '/BUILD')
    vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
    please.run()
    input_fake:enter_input('')
    -- WHEN we call action_history
    please.action_history()
    -- THEN the action history entry should not include the empty program args
    select_fake:assert_prompt('Pick action to run again')
    select_fake:assert_items({ 'Run //:foo1' })

    teardown_tree()
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
      local root, teardown_tree = create_temp_tree()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call yank
      please.yank()
      -- THEN the label of the target which the file is an input for is yanked into the " and * registers
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local select_fake = SelectFake:new()

      -- GIVEN we've yanked a build target's label
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.yank()
      -- fill the yank registers to make sure that we actually yank again below
      vim.fn.setreg('"', 'foo')
      vim.fn.setreg('*', 'foo')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Yank //:foo1_and_foo2' })
      -- WHEN we select the yank action
      select_fake:choose_item('Yank //:foo1_and_foo2')
      -- THEN the label is yanked again
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)

    it("should prompt user to choose which target's label to yank if there is more than one", function()
      local root, teardown_tree = create_temp_tree()
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

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should yank target under cursor', function()
      local root, teardown_tree = create_temp_tree()

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

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local select_fake = SelectFake:new()

      -- GIVEN we've yanked a build target's label
      vim.cmd('edit ' .. root .. '/BUILD')
      vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1
      please.yank()
      -- fill the yank registers to make sure that we actually yank again below
      vim.fn.setreg('"', 'foo')
      vim.fn.setreg('*', 'foo')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      select_fake:assert_prompt('Pick action to run again')
      select_fake:assert_items({ 'Yank //:foo1' })
      -- WHEN we select the yank action
      select_fake:choose_item('Yank //:foo1')
      -- THEN the label is yanked again
      assert.equal('//:foo1', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.equal('//:foo1', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)
  end)
end)

describe('action_history', function()
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

  it('should order history items from most to least recent', function()
    local root, teardown_tree = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've yanked the label of three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.yank()
    end
    -- WHEN we call action_history
    please.action_history()
    -- THEN the actions to yank each label are ordered from most to least recent
    select_fake:assert_items({ 'Yank //:foo3', 'Yank //:foo2', 'Yank //:foo1' })

    teardown_tree()
  end)

  it('should move rerun action to the top of history', function()
    local root, teardown_tree = create_temp_tree()
    local select_fake = SelectFake:new()

    -- GIVEN we've yanked the label of three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.yank()
    end
    -- WHEN we call action_history
    please.action_history()
    -- AND rerun the second action
    select_fake:assert_items({ 'Yank //:foo3', 'Yank //:foo2', 'Yank //:foo1' })
    select_fake:choose_item('Yank //:foo2')
    -- THEN it has been moved to the top of the history
    please.action_history()
    select_fake:assert_items({ 'Yank //:foo2', 'Yank //:foo3', 'Yank //:foo1' })

    teardown_tree()
  end)
end)
