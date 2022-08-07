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
      name = 'should not return directory which matches BUILD file name',
      tree = {
        '.plzconfig',
        'BUILD/',
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
      name = 'should return position for target at the start of a BUILD file',
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
      expected_position = { 1, 1 },
    },
    {
      name = 'should return position for target in the middle of a BUILD file',
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
      expected_position = { 6, 1 },
    },
    {
      name = 'should return position for target which is indented',
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
      expected_position = { 1, 3 },
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
      expected_position = { 1, 1 },
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

      local filepath, position, err = parsing.locate_build_target(root, case.label)

      if case.expected_filepath then
        assert.are.equal(root .. '/' .. case.expected_filepath, filepath, 'incorrect filepath')
      end

      if case.expected_position then
        assert.are.same(case.expected_position, position, 'incorrect position')
      end

      if case.expected_err then
        assert.are.equal(case.expected_err, err, 'incorrect error')
        assert.is_nil(filepath, 'expected no filepath')
        assert.is_nil(position, 'expected no position')
      else
        assert.is_nil(err, 'expected no error')
      end
    end)
  end
end)

describe('get_test_at_cursor', function()
  local run_test = function(case)
    local root, teardown = temptree.create_temp_tree(case.tree)
    teardowns:add(teardown)

    vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])
    cursor.set(case.cursor)

    if case.raises_error then
      assert.has_error(function()
        parsing.get_test_at_cursor()
      end, case.expected_err, 'incorrect error')
      return
    end

    local func_name, err = parsing.get_test_at_cursor()

    if case.expected_name then
      assert.are.equal(case.expected_name, func_name, 'incorrect name')
    end

    if case.expected_err then
      assert.is_nil(func_name, 'expected no name')
      assert.are.equal(case.expected_err, err, 'incorrect err')
    else
      assert.is_nil(err, 'expected no err')
    end
  end

  local run_tests = function(cases)
    for _, case in ipairs(cases) do
      it(case.name, function()
        run_test(case)
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
        expected_name = 'TestFunc$',
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
      {
        name = 'should return name of method if cursor is inside testify suite test method definition',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func (s *fooSuite) TestMethod() {
                s.Fail("oh no")
            }]],
        },
        cursor = { 2, 4 },
        expected_name = '/TestMethod$',
      },
      {
        name = 'should return error if testify suite method name does not start with Test',
        tree = {
          ['foo_test.go'] = strings.dedent [[
            func (s *fooSuite) Method() {
                s.Fail("oh no")
            }]],
        },
        cursor = { 2, 1 },
        expected_err = 'cursor is not in a test function',
      },
    }
  end)

  describe('for python', function()
    run_tests {
      {
        name = 'should return name of method if cursor is inside unittest test method definition',
        tree = {
          ['foo_test.py'] = strings.dedent [[
            class TestFoo(unittest.TestCase):
                def test_method(self):
                    self.assertEqual(1, 2)
                ]],
        },
        cursor = { 3, 5 },
        expected_name = 'TestFoo.test_method',
      },
      {
        name = 'should return error if unittest method name does not start with test_',
        tree = {
          ['foo_test.py'] = strings.dedent [[
            class TestFoo(unittest.TestCase):
                def method(self):
                    self.assertEqual(1, 2)
                ]],
        },
        cursor = { 3, 5 },
        expected_err = 'cursor is not in a test function',
      },
      {
        name = 'should return error if class name does not start with Test',
        tree = {
          ['foo_test.py'] = strings.dedent [[
            class Foo:
                def test_method(self):
                    self.assertEqual(1, 2)
                ]],
        },
        cursor = { 3, 5 },
        expected_err = 'cursor is not in a test function',
      },
    }
  end)

  describe('should return name of func if cursor is inside test func definition', function()
    local tree = {
      ['foo_test.go'] = strings.dedent [[
        func TestFunc(t *testing.T) {
            t.Fatal("oh no")
        }]],
    }

    local test_cases = {
      {
        name = 'first char',
        cursor = { 1, 1 },
      },
      {
        name = 'body',
        cursor = { 2, 1 },
      },
      {
        name = 'last char',
        cursor = { 3, 1 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test {
          tree = tree,
          cursor = case.cursor,
          expected_name = 'TestFunc$',
        }
      end)
    end
  end)

  describe('should return error if cursor is outside test func definition', function()
    local tree = {
      ['foo_test.go'] = strings.dedent [[

         func TestFunc(t *testing.T) {
            t.Fatal("oh no")
        } -- comment here so that autoformatter doesn't remove trailing space

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
        name = 'after last row',
        cursor = { 1, 1 },
      },
      {
        name = 'before first row',
        cursor = { 1, 1 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test {
          tree = tree,
          cursor = case.cursor,
          expected_err = 'cursor is not in a test function',
        }
      end)
    end
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
      expected_name = 'TestFuncTwo$',
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

    vim.cmd('edit ' .. root .. '/' .. case.file)
    cursor.set(case.cursor)

    if case.raises_err then
      assert.has_error(function()
        parsing.get_target_at_cursor(root)
      end, case.expected_err, 'incorrect error')
      return
    end

    local label, rule, err = parsing.get_target_at_cursor(root)

    if case.expected_label then
      assert.are.equal(case.expected_label, label, 'incorrect label')
    end
    if case.expected_rule then
      assert.are.equal(case.expected_rule, rule, 'incorrect rule')
    end

    if case.expected_err then
      assert.is_not_nil(err, 'expected error')
      assert.are.equal(case.expected_err, err, 'incorrect error')
      assert.is_nil(label, 'expected no label')
      assert.is_nil(rule, 'expected no rule')
    else
      assert.is_nil(err, 'expected no error')
    end
  end

  describe('should return label and rule of target when cursor is inside build target definition', function()
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
          file = 'BUILD',
          cursor = case.cursor,
          expected_label = '//:foo',
          expected_rule = 'export_file',
        }
      end)
    end
  end)

  it('should return label of target in BUILD file in child dir of root', function()
    local tree = {
      ['pkg/'] = {
        BUILD = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
      },
    }

    run_test {
      tree = tree,
      file = 'pkg/BUILD',
      cursor = { 2, 1 },
      expected_label = '//pkg:foo',
    }
  end)

  it('should return label and rule when there are multiple build targets in the BUILD file', function()
    run_test {
      tree = {
        BUILD = strings.dedent [[
          filegroup(
              name = "foo1",
              srcs = ["foo1.txt"],
          )

          export_file(
              name = "foo2",
              src = "foo2.txt",
          )]],
      },
      file = 'BUILD',
      cursor = { 7, 4 },
      expected_label = '//:foo2',
      expected_rule = 'export_file',
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
          file = 'BUILD',
          cursor = case.cursor,
          expected_err = 'cursor is not in a build target definition',
        }
      end)
    end
  end)

  it('should return label when rule uses single quotes', function()
    run_test {
      tree = {
        BUILD = strings.dedent [[
          export_file(
              name = 'foo',
              # src = 'foo2.txt',
          )]],
      },
      file = 'BUILD',
      cursor = { 1, 1 },
      expected_label = '//:foo',
    }
  end)

  it('should raise error if root is not absolute', function()
    assert.has_error(function()
      parsing.get_target_at_cursor 'repo'
    end, 'root must be absolute, got "repo"', 'incorrect error')
  end)

  it('should raise error if file is not a BUILD file', function()
    run_test {
      tree = {
        ['hello.py'] = 'print("Hello, World!")',
      },
      file = 'hello.py',
      cursor = { 1, 1 },
      raises_err = true,
      expected_err = 'file (python) is not a BUILD file',
    }
  end)
end)

teardowns:teardown()
