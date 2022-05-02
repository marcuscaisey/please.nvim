local strings = require 'plenary.strings'
local stub = require 'luassert.stub'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local please = require 'please.please'
local runners = require 'please.runners'
local cursor = require 'please.cursor'

local teardowns = TeardownFuncs:new()

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
    assert.are.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
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

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call build
    please.build()

    -- THEN the target is built in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--interactive_output', '--colour', 'build', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
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

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set { 2, 5 }

    -- WHEN we call build
    please.build()

    -- THEN the target is built in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--interactive_output', '--colour', 'build', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
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

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call test
    please.test()

    -- THEN the target is tested in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--interactive_output', '--colour', 'test', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
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

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a test file and the cursor is inside a test function
    vim.cmd('edit ' .. root .. '/foo/foo_test.go')
    vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails

    -- WHEN we call test_under_cursor
    please.test { under_cursor = true }

    -- THEN the test function under the cursor is tested in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--interactive_output', '--colour', 'test', '//foo:test', 'TestFails' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
  end)
end)

describe('test_under_cursor', function() end)

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

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we call run
    please.run()

    -- THEN the target is run in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--interactive_output', '--colour', 'run', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
  end)
end)

teardowns:teardown()
