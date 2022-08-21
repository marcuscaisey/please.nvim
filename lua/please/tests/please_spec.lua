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
  local obj = {
    _root = root,
  }
  local stubbed_popup = stub(runners, 'popup', function(cmd, args)
    obj._popup_cmd, obj._popup_args = cmd, args
  end)
  obj._stubbed_popup = stubbed_popup
  self.__index = self
  return setmetatable(obj, self)
end

function MockPlzPopup:assert_called_with(args)
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
  it('should build target which uses file as input in a popup', function()
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

    local mock_plz_popup = MockPlzPopup:new()

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call build
    please.build()

    -- THEN the target is built in a popup
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

    -- THEN the target is built in a popup
    mock_plz_popup:assert_called_with { 'build', '//:foo' }

    mock_plz_popup:revert()
  end)
end)

describe('test', function()
  it('should test target which uses file as input in a popup', function()
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

    -- THEN the target is tested in a popup
    mock_plz_popup:assert_called_with { 'test', '//:foo' }

    mock_plz_popup:revert()
  end)

  it('should run test under the cursor when under_cursor=true', function()
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

    -- THEN the test function under the cursor is tested in a popup
    mock_plz_popup:assert_called_with { 'test', '//foo:test', 'TestFails$' }

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

    -- THEN the target is built in a popup
    mock_plz_popup:assert_called_with { 'test', '//:foo' }

    mock_plz_popup:revert()
  end)
end)

describe('run', function()
  it('should run target which uses file as input in a popup', function()
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

    -- THEN the target is run in a popup
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

    -- THEN the target is built in a popup
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
