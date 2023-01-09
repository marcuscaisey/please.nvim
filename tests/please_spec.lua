local please = require('please')
local cursor = require('please.cursor')
local temptree = require('tests.utils.temptree')
local mock = require('tests.utils.mock')

describe('jump_to_target', function()
  local create_temp_tree = function()
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
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.are.same({ 6, 1 }, cursor.get(), 'incorrect cursor position')

    teardown_tree()
  end)

  it('should add entry to action history', function()
    local root, teardown_tree = create_temp_tree()
    local mock_select = mock.Select:new()

    -- GIVEN we've jumped to a target
    vim.cmd('edit ' .. root .. '/foo2.txt')
    please.jump_to_target()
    -- AND we edit a different file
    vim.cmd('edit ' .. root .. '/foo1.txt')
    -- WHEN we call action_history
    please.action_history()
    -- THEN we're prompted to pick an action to run again
    mock_select:assert_prompt('Pick action to run again')
    mock_select:assert_items({ 'Jump to //:foo1_and_foo2' })
    -- WHEN we select the jump action
    mock_select:choose_item('Jump to //:foo1_and_foo2')
    -- THEN the BUILD file is opened again
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target again
    assert.are.same({ 6, 1 }, cursor.get(), 'incorrect cursor position')

    teardown_tree()
  end)

  it('should prompt user to choose which target to jump to if there is more than one', function()
    local root, teardown_tree = create_temp_tree()
    local mock_select = mock.Select:new()

    -- GIVEN we're editing a file referenced by multiple BUILD targets
    vim.cmd('edit ' .. root .. '/foo1.txt')
    -- WHEN we call jump_to_target
    please.jump_to_target()
    -- THEN we're prompted to choose which target to jump to
    mock_select:assert_prompt('Select target to jump to')
    mock_select:assert_items({ '//:foo1', '//:foo1_and_foo2' })
    -- WHEN we select one of the targets
    mock_select:choose_item('//:foo1_and_foo2')
    -- THEN the BUILD file containing the chosen build target is opened
    assert.are.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
    -- AND the cursor is moved to the build target
    assert.are.same({ 6, 1 }, cursor.get(), 'incorrect cursor position')

    teardown_tree()
  end)
end)

describe('build', function()
  local create_temp_tree = function()
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
      local mock_plz_popup = mock.PlzPopup:new(root)

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call build
      please.build()
      -- THEN the target which the file is an input for is built
      mock_plz_popup:assert_called_with({ 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.build()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Build //:foo1_and_foo2' })
      -- WHEN we select the build action
      mock_select:choose_item('Build //:foo1_and_foo2')
      -- THEN the target is built again
      mock_plz_popup:assert_called_with({ 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to build if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call build
      please.build()
      -- THEN we're prompted to choose which target to build
      mock_select:assert_prompt('Select target to build')
      mock_select:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the targets
      mock_select:choose_item('//:foo1_and_foo2')
      -- THEN the target is built
      mock_plz_popup:assert_called_with({ 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should build target under cursor', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 6, 5 }) -- inside definition of :foo1_and_foo2
      -- WHEN we call build
      please.build()
      -- THEN the target under the cursor is built
      mock_plz_popup:assert_called_with({ 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we've built a target
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 6, 5 }) -- inside definition of :foo1_and_foo2
      please.build()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Build //:foo1_and_foo2' })
      -- WHEN we select the build action
      mock_select:choose_item('Build //:foo1_and_foo2')
      -- THEN the target is built again
      mock_plz_popup:assert_called_with({ 'build', '//:foo1_and_foo2' })

      teardown_tree()
    end)
  end)
end)

describe('test', function()
  local create_temp_tree = function()
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
      local mock_plz_popup = mock.PlzPopup:new(root)

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      -- WHEN we call test
      please.test()
      -- THEN the target which the file is an input for is tested
      mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we've tested a file
      vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
      please.test()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Test //foo:foo1_and_foo2_test' })
      -- WHEN we select the test action
      mock_select:choose_item('Test //foo:foo1_and_foo2_test')
      -- THEN the target is tested again
      mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to test if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
      -- WHEN we call test
      please.test()
      -- THEN we're prompted to choose which target to test
      mock_select:assert_prompt('Select target to test')
      mock_select:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
      -- WHEN we select one of the targets
      mock_select:choose_item('//foo:foo1_and_foo2_test')
      -- THEN the test is run
      mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test' })

      teardown_tree()
    end)

    describe('with under_cursor=true', function()
      it('should run test under the cursor', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)

        -- GIVEN we're editing a test file and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        cursor.set({ 9, 5 }) -- inside body of TestFails
        -- WHEN we call test with under_cursor=true
        please.test({ under_cursor = true })
        -- THEN the test under the cursor is tested
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should add entry to action history', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)
        local mock_select = mock.Select:new()

        -- GIVEN we've tested the function under the cursor
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        cursor.set({ 9, 5 }) -- inside body of TestFails
        please.test({ under_cursor = true })
        -- WHEN we call action_history
        please.action_history()
        -- THEN we're prompted to pick an action to run again
        mock_select:assert_prompt('Pick action to run again')
        mock_select:assert_items({ 'Test //foo:foo1_and_foo2_test (TestFails)' })
        -- WHEN we select the test action
        mock_select:choose_item('Test //foo:foo1_and_foo2_test (TestFails)')
        -- THEN the test is run again
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should prompt user to choose which target to test if there is more than one', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)
        local mock_select = mock.Select:new()

        -- GIVEN we're editing a test file referenced by multiple build targets and the cursor is inside a test function
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        cursor.set({ 9, 5 }) -- inside body of TestFails
        -- WHEN we call test with under_cursor=true
        please.test({ under_cursor = true })
        -- THEN we're prompted to choose which target to test
        mock_select:assert_prompt('Select target to test')
        mock_select:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
        -- WHEN we select one of the targets
        mock_select:choose_item('//foo:foo1_and_foo2_test')
        -- THEN the test is run
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)
    end)

    describe('with list=true', function()
      it('should prompt user to choose which test to run', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)
        local mock_select = mock.Select:new()

        -- GIVEN we're editing a test file
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        -- WHEN we call test with list=true
        please.test({ list = true })
        -- THEN we're prompted to pick a test from the test file
        mock_select:assert_prompt('Select test to run')
        mock_select:assert_items({ 'TestPasses', 'TestFails' })
        -- WHEN we select one of the tests
        mock_select:choose_item('TestFails')
        -- THEN the test is run
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should add entry to action history', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)
        local mock_select = mock.Select:new()

        -- GIVEN we've chosen a test to run from a list
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.test({ list = true })
        mock_select:choose_item('TestFails')
        -- WHEN we call action_history
        please.action_history()
        -- THEN we're prompted to pick an action to run again
        mock_select:assert_prompt('Pick action to run again')
        mock_select:assert_items({ 'Test //foo:foo1_and_foo2_test (TestFails)' })
        -- WHEN we select the test action
        mock_select:choose_item('Test //foo:foo1_and_foo2_test (TestFails)')
        -- THEN the test is run again
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)

      it('should prompt user to choose which target to test if there is more than one', function()
        local root, teardown_tree = create_temp_tree()
        local mock_plz_popup = mock.PlzPopup:new(root)
        local mock_select = mock.Select:new()

        -- GIVEN we're editing a test file referenced by multiple build targets
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        -- WHEN we call test with list=true
        please.test({ list = true })
        -- THEN we're prompted to pick a test from the test file
        mock_select:assert_prompt('Select test to run')
        mock_select:assert_items({ 'TestPasses', 'TestFails' })
        -- WHEN we select one of the tests
        mock_select:choose_item('TestFails')
        -- THEN we're prompted to choose which target to test
        mock_select:assert_prompt('Select target to test')
        mock_select:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
        -- WHEN we select one of the targets
        mock_select:choose_item('//foo:foo1_and_foo2_test')
        -- THEN the test is run
        mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })

        teardown_tree()
      end)
    end)
  end)

  describe('in BUILD file', function()
    it('should test target under cursor', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      cursor.set({ 2, 5 }) -- inside definition of :foo1_test
      -- WHEN we call test
      please.test()
      -- THEN the target is tested
      mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_test' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we've tested a build target
      vim.cmd('edit ' .. root .. '/foo/BUILD')
      cursor.set({ 2, 5 }) -- inside definition of :foo1_test
      please.test()
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Test //foo:foo1_test' })
      -- WHEN we select the test action
      mock_select:choose_item('Test //foo:foo1_test')
      -- THEN the target is tested again
      mock_plz_popup:assert_called_with({ 'test', '//foo:foo1_test' })

      teardown_tree()
    end)
  end)

  describe('with failed=true', function()
    it('should run test with --failed', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
      -- WHEN we call test with failed=true
      please.test({ failed = true })
      -- THEN test is run with --failed
      mock_plz_popup:assert_called_with({ 'test', '--failed' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()

      -- GIVEN we've run the failed tests
      vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
      please.test({ failed = true })
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Run previously failed tests' })
      -- WHEN we select the test action
      mock_select:choose_item('Run previously failed tests')
      -- THEN test is run with --failed again
      mock_plz_popup:assert_called_with({ 'test', '--failed' })

      teardown_tree()
    end)
  end)
end)

describe('run', function()
  local create_temp_tree = function()
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
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_input = mock.Input:new()

      -- GIVEN we're editing a file
      vim.cmd('edit ' .. root .. '/foo2.txt')
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to enter arguments for the program
      mock_input:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      mock_input:enter_input('--foo foo --bar bar')
      -- THEN the target which the file is an input for is run with those arguments
      mock_plz_popup:assert_called_with({ 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_input = mock.Input:new()
      local mock_select = mock.Select:new()

      -- GIVEN that we've run a build target
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.run()
      mock_input:enter_input('--foo foo --bar bar')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Run //:foo1_and_foo2 --foo foo --bar bar' })
      -- WHEN we select the run action
      mock_select:choose_item('Run //:foo1_and_foo2 --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      mock_plz_popup:assert_called_with({ 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)

    it('should prompt user to choose which target to run if there is more than one', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_select = mock.Select:new()
      local mock_input = mock.Input:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to choose which target to run
      mock_select:assert_prompt('Select target to run')
      mock_select:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the targets
      mock_select:choose_item('//:foo1_and_foo2')
      -- THEN we're prompted to enter arguments for the program
      mock_input:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      mock_input:enter_input('--foo foo --bar bar')
      -- THEN the target is run with those arguments
      mock_plz_popup:assert_called_with({ 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should run target under cursor', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_input = mock.Input:new()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 2, 5 }) -- in definition of :foo1
      -- WHEN we call run
      please.run()
      -- THEN we're prompted to enter arguments for the program
      mock_input:assert_prompt('Enter program arguments')
      -- WHEN we enter some program arguments
      mock_input:enter_input('--foo foo --bar bar')
      -- THEN the target is run with those arguments
      mock_plz_popup:assert_called_with({ 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_plz_popup = mock.PlzPopup:new(root)
      local mock_input = mock.Input:new()
      local mock_select = mock.Select:new()

      -- GIVEN we've run a build target
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 2, 5 }) -- in definition of :foo1
      please.run()
      mock_input:enter_input('--foo foo --bar bar')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Run //:foo1 --foo foo --bar bar' })
      -- WHEN we select the run action
      mock_select:choose_item('Run //:foo1 --foo foo --bar bar')
      -- THEN the target is run again with the same arguments
      mock_plz_popup:assert_called_with({ 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })

      teardown_tree()
    end)
  end)

  it('should not include program args in action history entry when none are passed as input', function()
    local root, teardown_tree = create_temp_tree()
    local mock_input = mock.Input:new()
    local mock_select = mock.Select:new()

    -- GIVEN we've run a build target and passed no arguments
    vim.cmd('edit ' .. root .. '/BUILD')
    cursor.set({ 2, 5 }) -- in definition of :foo1
    please.run()
    mock_input:enter_input('')
    -- WHEN we call action_history
    please.action_history()
    -- THEN the action history entry should not include the empty program args
    mock_select:assert_prompt('Pick action to run again')
    mock_select:assert_items({ 'Run //:foo1' })

    teardown_tree()
  end)
end)

describe('yank', function()
  local create_temp_tree = function()
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
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_select = mock.Select:new()

      -- GIVEN we've yanked a build target's label
      vim.cmd('edit ' .. root .. '/foo2.txt')
      please.yank()
      -- fill the yank registers to make sure that we actually yank again below
      vim.fn.setreg('"', 'foo')
      vim.fn.setreg('*', 'foo')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Yank //:foo1_and_foo2' })
      -- WHEN we select the yank action
      mock_select:choose_item('Yank //:foo1_and_foo2')
      -- THEN the label is yanked again
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)

    it("should prompt user to choose which target's label to yank if there is more than one", function()
      local root, teardown_tree = create_temp_tree()
      local mock_select = mock.Select:new()

      -- GIVEN we're editing a file referenced by multiple build targets
      vim.cmd('edit ' .. root .. '/foo1.txt')
      -- WHEN we call yank
      please.yank()
      -- THEN we're prompted to choose which label to yank
      mock_select:assert_prompt('Select label to yank')
      mock_select:assert_items({ '//:foo1', '//:foo1_and_foo2' })
      -- WHEN we select one of the labels
      mock_select:choose_item('//:foo1_and_foo2')
      -- THEN the label is yanked into the " and * registers
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.are.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)
  end)

  describe('in BUILD file', function()
    it('should yank target under cursor', function()
      local root, teardown_tree = create_temp_tree()

      -- GIVEN we're editing a BUILD file and our cursor is inside a BUILD target definition
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 2, 5 }) -- inside definition of :foo1
      -- WHEN we call yank
      please.yank()
      -- THEN the target's label is yanked into the " and * register
      local unnamed = vim.fn.getreg('"')
      local star = vim.fn.getreg('*')
      assert.are.equal('//:foo1', unnamed, 'incorrect value in " register')
      assert.are.equal('//:foo1', star, 'incorrect value in * register')

      teardown_tree()
    end)

    it('should add entry to action history', function()
      local root, teardown_tree = create_temp_tree()
      local mock_select = mock.Select:new()

      -- GIVEN we've yanked a build target's label
      vim.cmd('edit ' .. root .. '/BUILD')
      cursor.set({ 2, 5 }) -- inside definition of :foo1
      please.yank()
      -- fill the yank registers to make sure that we actually yank again below
      vim.fn.setreg('"', 'foo')
      vim.fn.setreg('*', 'foo')
      -- WHEN we call action_history
      please.action_history()
      -- THEN we're prompted to pick an action to run again
      mock_select:assert_prompt('Pick action to run again')
      mock_select:assert_items({ 'Yank //:foo1' })
      -- WHEN we select the yank action
      mock_select:choose_item('Yank //:foo1')
      -- THEN the label is yanked again
      assert.are.equal('//:foo1', vim.fn.getreg('"'), 'incorrect value in " register')
      assert.are.equal('//:foo1', vim.fn.getreg('*'), 'incorrect value in * register')

      teardown_tree()
    end)
  end)
end)

describe('action_history', function()
  local create_temp_tree = function()
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
    local mock_select = mock.Select:new()

    -- GIVEN we've yanked the label of three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.yank()
    end
    -- WHEN we call action_history
    please.action_history()
    -- THEN the actions to yank each label are ordered from most to least recent
    mock_select:assert_items({ 'Yank //:foo3', 'Yank //:foo2', 'Yank //:foo1' })

    teardown_tree()
  end)

  it('should move rerun action to the top of history', function()
    local root, teardown_tree = create_temp_tree()
    local mock_select = mock.Select:new()

    -- GIVEN we've yanked the label of three targets, one after the other
    for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
      vim.cmd('edit ' .. root .. '/' .. filename)
      please.yank()
    end
    -- WHEN we call action_history
    please.action_history()
    -- AND rerun the second action
    mock_select:assert_items({ 'Yank //:foo3', 'Yank //:foo2', 'Yank //:foo1' })
    mock_select:choose_item('Yank //:foo2')
    -- THEN it has been moved to the top of the history
    please.action_history()
    mock_select:assert_items({ 'Yank //:foo2', 'Yank //:foo3', 'Yank //:foo1' })

    teardown_tree()
  end)
end)
