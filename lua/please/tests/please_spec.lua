local strings = require 'plenary.strings'
local stub = require 'luassert.stub'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local please = require 'please.please'
local runners = require 'please.runners'
local input = require 'please.input'

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

    local select_items, select_prompt, select_callback
    local stubbed_select_if_required = stub(input, 'select_if_required', function(items, prompt, callback)
      select_items, select_prompt, select_callback = items, prompt, callback
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo2.txt')

    -- WHEN we jump_to_target
    please.jump_to_target()

    -- THEN the user is prompted to select which build target to jump to if required
    assert.are.same({ '//:foo2' }, select_items, 'incorrect select items')
    assert.are.equal('Select target to jump to', select_prompt, 'incorrect select prompt')

    select_callback '//:foo2'
    -- AND the BUILD file containing the chosen build target for the file is opened
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.are.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')

    stubbed_select_if_required:revert()
  end)
end)

describe('build_target', function()
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

    local select_items, select_prompt, select_callback
    local stubbed_select_if_required = stub(input, 'select_if_required', function(items, prompt, callback)
      select_items, select_prompt, select_callback = items, prompt, callback
    end)

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we build_target
    please.build_target()

    -- THEN the user is prompted to select which target to build if required
    assert.are.same({ '//:foo' }, select_items, 'incorrect select items')
    assert.are.equal('Select target to build', select_prompt, 'incorrect select prompt')

    select_callback '//:foo'
    -- AND the target is built in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--verbosity', 'info', 'build', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
    stubbed_select_if_required:revert()
  end)
end)

describe('test_file', function()
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

    local select_items, select_prompt, select_callback
    local stubbed_select_if_required = stub(input, 'select_if_required', function(items, prompt, callback)
      select_items, select_prompt, select_callback = items, prompt, callback
    end)

    local popup_cmd, popup_args
    local stubbed_popup = stub(runners, 'popup', function(cmd, args)
      popup_cmd, popup_args = cmd, args
    end)

    -- GIVEN we're editing a file
    vim.cmd('edit ' .. root .. '/foo.txt')

    -- WHEN we test_file
    please.test_file()

    -- THEN the user is prompted to select which target to test if required
    assert.are.same({ '//:foo' }, select_items, 'incorrect select items')
    assert.are.equal('Select target to test', select_prompt, 'incorrect select prompt')

    select_callback '//:foo'
    -- AND the target is tested in a popup
    assert.are.equal('plz', popup_cmd, 'incorrect command passed to popup')
    assert.are.same(
      { '--repo_root', root, '--verbosity', 'info', '--colour', 'test', '//:foo' },
      popup_args,
      'incorrect args passed to popup'
    )

    stubbed_popup:revert()
    stubbed_select_if_required:revert()
  end)
end)

teardowns:teardown()
