local strings = require 'plenary.strings'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local cursor = require 'please.cursor'
local parsing = require 'please.parsing'

local teardowns = TeardownFuncs:new()

describe('locate_build_target', function()
  local test_cases = {
    {
      name = 'should return location of a BUILD file in the root of the repo',
      tree = {
        '.plzconfig',
        BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_filepath = 'BUILD',
    },
    {
      name = 'should return location of a BUILD file in a child dir of the repo',
      tree = {
        '.plzconfig',
        ['foo/'] = {
          BUILD = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
          'foo.txt',
        },
      },
      label = '//foo:foo',
      expected_filepath = 'foo/BUILD',
    },
    {
      name = 'should return location of a BUILD.plz file',
      tree = {
        '.plzconfig',
        ['BUILD.plz'] = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_filepath = 'BUILD.plz',
    },
    {
      name = 'should return error if pkg path exists but BUILD or BUILD.plz file does not',
      tree = {
        '.plzconfig',
        'no_targets/',
      },
      label = '//no_targets:target',
      expected_err = 'no build file exists for package "no_targets"',
    },
    {
      name = 'should return error if pkg path does not exist',
      tree = { '.plzconfig' },
      label = '//does/not/exist:target',
      expected_err = 'no build file exists for package "does/not/exist"',
    },
    {
      name = 'should return line and col for target at the start of a BUILD file',
      tree = {
        '.plzconfig',
        BUILD = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_line = 1,
      expected_col = 1,
    },
    {
      name = 'should return line and col for target in the middle of a BUILD file',
      tree = {
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
        'foo1.txt',
        'foo2.txt',
      },
      label = '//:foo2',
      expected_line = 6,
      expected_col = 1,
    },
    {
      name = 'should return line and col for target which is indented',
      tree = {
        '.plzconfig',
        BUILD = strings.dedent [[
            export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_line = 1,
      expected_col = 3,
    },
    {
      name = 'should return first line and column if target cannot be found in BUILD file',
      tree = {
        '.plzconfig',
        BUILD = strings.dedent [[
          export_file(
              name = "not_foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_line = 1,
      expected_col = 1,
    },
    {
      name = 'should raise error if root is not absolute',
      root = 'repo',
      label = '//foo:foo',
      raises_error = true,
      expected_err = 'root must be absolute, got "repo"',
    },
    {
      name = 'should raise error if label is relative',
      root = '/tmp/root',
      label = ':foo',
      raises_error = true,
      expected_err = 'label must be in //path/to/pkg:target format, got ":foo"',
    },
    {
      name = 'should raise error if label does not have target',
      root = '/tmp/root',
      label = '//foo',
      raises_error = true,
      expected_err = 'label must be in //path/to/pkg:target format, got "//foo"',
    },
    {
      name = 'should raise error if label is not a build label',
      root = '/tmp/root',
      label = 'foo',
      raises_error = true,
      expected_err = 'label must be in //path/to/pkg:target format, got "foo"',
    },
  }

  for _, case in ipairs(test_cases) do
    it(case.name, function()
      if case.raises_error then
        assert.has_error(function()
          parsing.locate_build_target(case.root, case.label)
        end, case.expected_err, 'incorrect error')
        return
      end

      local root, teardown = temptree.create_temp_tree(case.tree)
      teardowns:add(teardown)

      local filepath, line, col, err = parsing.locate_build_target(root, case.label)

      if case.expected_filepath then
        assert.are.equal(root .. '/' .. case.expected_filepath, filepath, 'incorrect filepath')
      end

      if case.expected_line then
        assert.are.equal(case.expected_line, line, 'incorrect line')
      end

      if case.expected_col then
        assert.are.equal(case.expected_col, col, 'incorrect col')
      end

      if case.expected_err then
        assert.are.equal(case.expected_err, err, 'incorrect error')
        assert.is_nil(filepath, 'expected no filepath')
        assert.is_nil(line, 'expected no line')
        assert.is_nil(col, 'expected no col')
      else
        assert.is_nil(err, 'expected no error')
      end
    end)
  end
end)

describe('get_test_at_cursor', function()
  local run_tests = function(cases)
    for _, case in ipairs(cases) do
      it(case.name, function()
        local root, teardown = temptree.create_temp_tree(case.tree)
        teardowns:add(teardown)
        vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])

        cursor.set(case.cursor)

        if case.expected_name then
          local func_name, err = parsing.get_test_at_cursor()
          assert.are.equal(case.expected_name, func_name, 'incorrect name')
          assert.is_nil(err, 'expected no err')
        elseif case.raises_error then
          assert.has_error(function()
            parsing.get_test_at_cursor()
          end, case.expected_err, 'incorrect error')
        elseif case.expected_err then
          local func_name, err = parsing.get_test_at_cursor()
          assert.is_nil(func_name, 'expected no name')
          assert.are.equal(case.expected_err, err, 'incorrect err')
        end
      end)
    end
  end

  describe('for go', function()
    run_tests {
      {
        name = 'should return name of func if cursor is inside test func definition',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 2, 4 },
        expected_name = 'TestFunc',
      },
      {
        name = 'should return name of method if cursor is inside testify suite test method definition',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func (s *fooSuite) TestMethod() {
                s.Fail("oh no")
            }]],
        },
        cursor = { 2, 4 },
        expected_name = '/TestMethod',
      },
      {
        name = 'should return name of parent test func if cursor is in a subtest',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func TestFunc(t *testing.T) {
                t.Run("SubTest", func(t *testing.T) {
                    t.Fatalf("oh no")
                })
            }]],
        },
        cursor = { 3, 8 },
        expected_name = 'TestFunc',
      },
      {
        name = 'should return error if func name does not start with Test',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func Func(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 2, 1 },
        expected_err = 'cursor is not in a test function',
      },
    }
  end)

  run_tests {
    {
      name = 'should return name of func if there are multiple test funcs in the file',
      tree = {
        ['foo_test.go'] = strings.dedent [[
            func TestFuncOne(t *testing.T) {
                t.Fatal("oh no")
            }

            func TestFuncTwo(t *testing.T) {
                t.Fatal("oh no")
            }]],
      },
      cursor = { 6, 4 },
      expected_name = 'TestFuncTwo',
    },
    {
      name = 'should return error is outside test func definition',
      tree = {
        ['foo_test.go'] = strings.dedent [[

             func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
      },
      cursor = { 1, 1 },
      expected_err = 'cursor is not in a test function',
    },
    {
      name = 'should raise error if language of file is not supported',
      tree = {
        ['hello.rb'] = 'puts "Hello, World!"',
      },
      cursor = { 1, 1 },
      raises_error = true,
      expected_err = 'finding tests is not supported for ruby files',
    },
  }
end)

describe('get_target_at_cursor', function()
  local run_test = function(case)
    local root, teardown = temptree.create_temp_tree(case.tree)
    teardowns:add(teardown)

    vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])
    cursor.set(case.cursor)

    if case.raises_err then
      assert.has_error(function()
        parsing.get_target_at_cursor()
      end, case.expected_err, 'incorrect error')
      return
    end

    local target, err = parsing.get_target_at_cursor()

    if case.expected_target then
      assert.are.equal(case.expected_target, target, 'incorrect target')
    end

    if case.expected_err then
      assert.is_not_nil(err, 'expected error')
      assert.are.equal(case.expected_err, err, 'incorrect error')
      assert.is_nil(target, 'expected no target')
    else
      assert.is_nil(err, 'expected no error')
    end
  end

  describe('should return name of target when cursor is inside build target definition', function()
    local tree = {
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
    }

    local test_cases = {
      {
        name = 'first char',
        cursor = { 1, 1 },
      },
      {
        name = 'middle row',
        cursor = { 2, 1 },
      },
      {
        name = 'last char',
        cursor = { 4, 1 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test {
          tree = tree,
          cursor = case.cursor,
          expected_target = 'foo',
        }
      end)
    end
  end)

  it('should return name of target when there are multiple build targets in the BUILD file', function()
    run_test {
      tree = {
        BUILD = strings.dedent [[
          export_file(
              name = "foo1",
              src = "foo1.txt",
          )

          export_file(
              name = "foo2",
              src = "foo2.txt",
          )]],
      },
      cursor = { 7, 4 },
      expected_target = 'foo2',
    }
  end)

  describe('should return error when cursor is outside build target definition', function()
    local tree = {
      BUILD = strings.dedent [[

         export_file(
            name = "foo",
            src = "foo.txt",
        ) -- this comment stops the space after the last char getting removed by autoformatting
         ]],
    }

    local test_cases = {
      {
        name = 'before first row',
        cursor = { 1, 1 },
      },
      {
        name = 'before first char',
        cursor = { 2, 1 },
      },
      {
        name = 'after last char',
        cursor = { 5, 2 },
      },
      {
        name = 'after last row',
        cursor = { 6, 1 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test {
          tree = tree,
          cursor = case.cursor,
          expected_err = 'cursor is not in a build target definition',
        }
      end)
    end
  end)

  it('should raise error if file is not a BUILD file', function()
    run_test {
      tree = {
        ['hello.py'] = 'print("Hello, World!")',
      },
      cursor = { 1, 1 },
      raises_err = true,
      expected_err = 'file (python) is not a BUILD file',
    }
  end)
end)

teardowns:teardown()
