local strings = require 'plenary.strings'
local stub = require 'luassert.stub'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local please = require 'please.please'
local runners = require 'please.runners'
local cursor = require 'please.cursor'

-- TODO: get rid of this, i don't know why i thought it was a good idea lol
local teardowns = TeardownFuncs:new()

local MockPlzPopup = {}

function MockPlzPopup:new(root)
  assert.is_not_nil(root, 'root must be passed to MockPlzPopup')
  local obj = {
    _root = root,
    _popup_called = false,
  }
  local stubbed_popup = stub(runners, 'popup', function(cmd, args)
    obj._popup_cmd, obj._popup_args = cmd, args
    obj._popup_called = true
  end)
  obj._stubbed_popup = stubbed_popup
  self.__index = self
  return setmetatable(obj, self)
end

function MockPlzPopup:assert_called_with(args)
  if not self._popup_called then
    error 'cannot assert on popup args before it has been called'
  end
  assert.are.equal('plz', self._popup_cmd, 'incorrect command passed to popup')
  assert.are.same(
    { '--repo_root', self._root, '--interactive_output', '--colour', unpack(args) },
    self._popup_args,
    'incorrect args passed to popup'
  )
end

function MockPlzPopup:revert()
  self._stubbed_popup:revert()
end

local MockSelect = {}

function MockSelect:new()
  local obj = {
    _select_called = false,
  }
  local stubbed_select = stub(vim.ui, 'select', function(items, opts, on_choice)
    obj._select_items, obj._select_opts, obj._select_on_choice = items, opts, on_choice
    obj._select_called = true
  end)
  obj._stubbed_select = stubbed_select
  self.__index = self
  return setmetatable(obj, self)
end

function MockSelect:assert_items(items)
  if not self._select_called then
    error 'cannot assert on vim.ui.select items before it has been called'
  end
  assert.are.same(items, self._select_items, 'incorrect items passed to vim.ui.select')
end

function MockSelect:assert_prompt(prompt)
  if not self._select_called then
    error 'cannot assert on vim.ui.select prompt before it has been called'
  end
  assert.is_not_nil(self._select_opts.prompt, 'expected prompt opt passed to vim.ui.select')
  assert.are.equal(prompt, self._select_opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
end

function MockSelect:choose_item(item)
  if not self._select_called then
    error 'cannot choose vim.ui.select item before it has been called'
  end
  if not vim.tbl_contains(self._select_items, item) then
    error(
      string.format(
        'cannot choose item "%s" which was not passed to vim.ui.select, available choices are: %s',
        item,
        vim.inspect(self._select_items)
      )
    )
  end
  for i, v in ipairs(self._select_items) do
    if v == item then
      self._select_on_choice(item, i)
    end
  end
end

function MockSelect:revert()
  self._stubbed_select:revert()
end

-- TODO: add back tests in here which test vim.ui.select usage
describe('jump_to_target', function()
  it('should jump from file to build target which uses it as an input', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        export_file(
            name = "foo2",
            src = "foo2.txt",
        )]],
      ['foo1.txt'] = 'foo1 content',
      ['foo2.txt'] = 'foo2 content',
    }
    teardowns:add(teardown)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo2.txt')

    -- WHEN we jump_to_target
    please.jump_to_target()

    -- THEN the BUILD file containing the chosen build target for the file is opened
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.are.same({ 6, 1 }, cursor.get(), 'incorrect cursor position')
  end)
end)

describe('build', function()
  it('should build target which uses file as input', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call build
    please.build()

    -- THEN the target is built
    mock_plz_popup:assert_called_with { 'build', '//:foo' }

    mock_plz_popup:revert()
  end)

  it('should build target under cursor when in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set { 2, 5 }

    -- WHEN we call build
    please.build()

    -- THEN the target is built
    mock_plz_popup:assert_called_with { 'build', '//:foo' }

    mock_plz_popup:revert()
  end)
end)

describe('test', function()
  it('should test target which uses file as input', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call test
    please.test()

    -- THEN the target is tested
    mock_plz_popup:assert_called_with { 'test', '//:foo' }

    mock_plz_popup:revert()
  end)

  it('should test target under cursor when in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set { 2, 5 }

    -- WHEN we call test
    please.test()

    -- THEN the target is tested
    mock_plz_popup:assert_called_with { 'test', '//:foo' }

    mock_plz_popup:revert()
  end)

  describe('with under_cursor=true', function()
    it('should run test under the cursor', function()
      local root, teardown = temptree.create_temp_tree {
        '.plzconfig',
        ['foo/'] = {
          BUILD = strings.dedent [[
          go_test(
              name = "test",
              srcs = glob(["*_test.go"]),
              external = True,
          )]],
          ['foo_test.go'] = strings.dedent [[
          package foo_test

          import "testing"

          func TestPasses(t *testing.T) {
          }

          func TestFails(t *testing.T) {
              t.Fatal("oh no")
          }]],
        },
      }
      teardowns:add(teardown)

      local mock_plz_popup = MockPlzPopup:new(root)

      -- GIVEN we're editing a test file and the cursor is inside a test function
      vim.cmd('edit ' .. root .. '/foo/foo_test.go')
      cursor.set { 9, 5 } -- inside body of TestFails

      -- WHEN we call test with under_cursor=true
      please.test { under_cursor = true }

      -- THEN the test function under the cursor is tested
      mock_plz_popup:assert_called_with { 'test', '//foo:test', 'TestFails$' }

      mock_plz_popup:revert()
    end)
  end)

  describe('with list=true', function()
    it('should prompt user to choose which test to run', function()
      local root, teardown_tree = temptree.create_temp_tree {
        '.plzconfig',
        ['foo/'] = {
          BUILD = [[
            go_test(
                name = "test",
                srcs = glob(["*_test.go"]),
                external = True,
            )
          ]],
          ['foo_test.go'] = [[
            package foo_test

            import "testing"

            func TestPasses(t *testing.T) {
            }

            func TestFails(t *testing.T) {
                t.Fatal("oh no")
            }
          ]],
        },
      }
      local mock_plz_popup = MockPlzPopup:new(root)
      local mock_select = MockSelect:new()

      -- GIVEN we're editing a test file
      vim.cmd('edit ' .. root .. '/foo/foo_test.go')

      -- WHEN we call test with list=true
      please.test { list = true }

      -- THEN we're prompted to pick a test from the test file
      mock_select:assert_items { 'TestPasses', 'TestFails' }
      mock_select:assert_prompt 'Select test to run'

      -- WHEN we select one of the tests
      mock_select:choose_item 'TestFails'

      -- THEN the test is run
      mock_plz_popup:assert_called_with { 'test', '//foo:test', 'TestFails$' }

      mock_plz_popup:revert()
      mock_select:revert()
      teardown_tree()
    end)

    it('should prompt user to choose which target to test if there is more than one', function()
      local root, teardown_tree = temptree.create_temp_tree {
        '.plzconfig',
        ['foo/'] = {
          BUILD = strings.dedent [[
            go_test(
                name = "test1",
                srcs = glob(["*_test.go"]),
                external = True,
            )

            go_test(
                name = "test2",
                srcs = glob(["*_test.go"]),
                external = True,
            )]],
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestPasses(t *testing.T) {
            }

            func TestFails(t *testing.T) {
                t.Fatal("oh no")
            }
          ]],
        },
      }
      local mock_plz_popup = MockPlzPopup:new(root)
      local mock_select = MockSelect:new()

      -- GIVEN we're editing a test file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo/foo_test.go')

      -- WHEN we call test with list=true
      please.test { list = true }

      -- THEN we're prompted to pick a test from the test file
      mock_select:assert_items { 'TestPasses', 'TestFails' }
      mock_select:assert_prompt 'Select test to run'

      -- WHEN we select one of the tests
      mock_select:choose_item 'TestFails'

      -- THEN we're prompted to choose which target to test
      mock_select:assert_items { '//foo:test1', '//foo:test2' }
      mock_select:assert_prompt 'Select target to test'

      -- WHEN we select one of the targets
      mock_select:choose_item '//foo:test2'

      -- THEN the test is run
      mock_plz_popup:assert_called_with { 'test', '//foo:test2', 'TestFails$' }

      mock_plz_popup:revert()
      mock_select:revert()
      teardown_tree()
    end)
  end)

  describe('with failed=true', function()
    it('should run test with --failed', function()
      local root, teardown_tree = temptree.create_temp_tree {
        '.plzconfig',
        BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
        ['foo.txt'] = 'foo content',
      }
      local mock_plz_popup = MockPlzPopup:new(root)

      -- GIVEN we're editing a file in the repo
      vim.cmd('edit ' .. root .. '/foo.txt')

      -- WHEN we call test with failed=true
      please.test { failed = true }

      -- THEN test is run with --failed
      mock_plz_popup:assert_called_with { 'test', '--failed' }

      mock_plz_popup:revert()
      teardown_tree()
    end)
  end)
end)

describe('run', function()
  it('should run target which uses file as input', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call run
    please.run()

    -- THEN the target is run
    mock_plz_popup:assert_called_with { 'run', '//:foo' }

    mock_plz_popup:revert()
  end)

  it('should run target under cursor when in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    local mock_plz_popup = MockPlzPopup:new(root)

    -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set { 2, 5 }

    -- WHEN we call run
    please.run()

    -- THEN the target is run
    mock_plz_popup:assert_called_with { 'run', '//:foo' }

    mock_plz_popup:revert()
  end)
end)

describe('yank', function()
  it('should yank label of target which uses file as input', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call yank
    please.yank()

    -- THEN the target's label is yanked into the " and * register
    local unnamed = vim.fn.getreg '"'
    local star = vim.fn.getreg '*'
    assert.are.equal('//:foo', unnamed, 'incorrect value in " register')
    assert.are.equal('//:foo', star, 'incorrect value in * register')
  end)

  it('should run target under cursor when in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set { 2, 5 }

    -- WHEN we call yank
    please.yank()

    -- THEN the target's label is yanked into the " and * register
    local unnamed = vim.fn.getreg '"'
    local star = vim.fn.getreg '*'
    assert.are.equal('//:foo', unnamed, 'incorrect value in " register')
    assert.are.equal('//:foo', star, 'incorrect value in * register')
  end)
end)

teardowns:teardown()
