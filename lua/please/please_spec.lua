local strings = require 'plenary.strings'
local stub = require 'luassert.stub'
local temptree = require 'please.testutils.temptree'
local TeardownFuncs = require 'please.testutils.teardowns'
local please = require 'please'

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

    -- THEN the BUILD file containing the build target for the file is opened
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.are.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
  end)

  it('should prompt for choice of targets when multiple targets exist', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo1",
            src = "foo.txt",
        )

        export_file(
            name = "foo2",
            src = "foo.txt",
        )]],
      ['foo.txt'] = 'foo content',
    }
    teardowns:add(teardown)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')
    -- AND the file is an input for two build targets
    local stubbed_select = stub(vim.ui, 'select', function(items, _, on_choice)
      assert.are.same({ '//:foo1', '//:foo2' }, items, 'incorrect items passed to vim.ui.select')
      on_choice '//:foo2'
    end)

    -- WHEN we jump_to_target and select one of the build target labels
    please.jump_to_target()

    -- THEN the BUILD file containing the build targets for the file is opened
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the selected build target
    assert.are.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')

    stubbed_select:revert()
  end)
end)

teardowns:teardown()
