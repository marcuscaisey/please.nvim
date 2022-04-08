local strings = require 'plenary.strings'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local parsing = require 'please.parsing'

local teardowns = TeardownFuncs:new()

describe('locate_build_target', function()
  it('should return location of a BUILD file in the root of the repo', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local filepath, _, _, err = parsing.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD file in a child dir of the repo', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        BUILD = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
    }
    teardowns:add(teardown)
    local label = '//foo:foo'

    local filepath, _, _, err = parsing.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/foo/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD.plz file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['BUILD.plz'] = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local filepath, _, _, err = parsing.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/BUILD.plz', filepath, 'incorrect filepath')
  end)

  it('should return error if pkg path exists but BUILD or BUILD.plz file does not', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      'no_targets/',
    }
    teardowns:add(teardown)
    local label = '//no_targets:target'

    local filepath, line, col, err = parsing.locate_build_target(root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    assert.are.equal('no build file exists for package "no_targets"', err)
  end)

  it('should return error if pkg path does not exist', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
    }
    teardowns:add(teardown)
    local label = '//does/not/exist:target'

    local filepath, line, col, err = parsing.locate_build_target(root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    assert.are.equal('no build file exists for package "does/not/exist"', err)
  end)

  it('should return line and col for target at the start of a BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = parsing.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target in the middle of a BUILD file', function()
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
      'foo1.txt',
      'foo2.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo2'

    local _, line, col, err = parsing.locate_build_target(root, label)

    assert.are.equal(6, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target which is indented', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
          export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = parsing.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(3, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return first line and column if target cannot be found in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "not_foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = parsing.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should raise error if root is not absolute', function()
    local root = 'repo'
    local label = '//foo:foo'

    assert.has_error(function()
      parsing.locate_build_target(root, label)
    end, 'root must be absolute, got "repo"')
  end)

  it('should raise error if label is relative', function()
    local root = '/tmp/root'
    local label = ':foo'

    assert.has_error(function()
      parsing.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got ":foo"')
  end)

  it('should raise error if label does not have target', function()
    local root = '/tmp/root'
    local label = '//foo'

    assert.has_error(function()
      parsing.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got "//foo"')
  end)

  it('should raise error if label is not a build label', function()
    local root = '/tmp/root'
    local label = 'foo'

    assert.has_error(function()
      parsing.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got "foo"')
  end)
end)

describe('get_test_at_cursor', function()
  it('should raise error if language of file is not supported', function()
    local root, teardown = temptree.create_temp_tree {
      ['hello.rb'] = 'puts "Hello, World!"',
    }
    teardowns:add(teardown)
    vim.cmd('edit ' .. root .. '/hello.rb')

    assert.has_error(function()
      parsing.get_test_at_cursor()
    end, 'finding tests is not supported for ruby files')
  end)

  describe('for go', function()
    local cases = {
      ['should return name of func if cursor is anywhere inside test func definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor_range = {
          start_row = 5,
          end_row = 7,
        },
        expected_name = 'TestFunc',
      },
      ['should return name of method if cursor is anywhere inside testify suite test method definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foobar_test

            import (
               "testing"

               "github.com/stretchr/testify/suite"
            )

            type fooSuite struct {
                suite.Suite
            }

            func TestFoo(t *testing.T) {
                suite.Run(t, &fooSuite{})
            }

            func (s *fooSuite) TestMethod() {
                s.Fail("oh no")
            }]],
        },
        cursor_range = {
          start_row = 17,
          end_row = 19,
        },
        expected_name = '/TestMethod',
      },
      ['should return name of func if there are multiple test funcs in the file'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFuncOne(t *testing.T) {
                t.Fatal("oh no")
            }

            func TestFuncTwo(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 10, 7 },
        expected_name = 'TestFuncTwo',
      },
      ['should return name of parent test func if cursor is in a subtest'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFunc(t *testing.T) {
                t.Run("SubTest", func(t *testing.T) {
                    t.Fatalf("oh no")
                })
            }]],
        },
        cursor = { 7, 11 },
        expected_name = 'TestFunc',
      },
      ['should return error if cursor is on char before test func definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

             func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 5, 1 },
        expected_err = 'cursor is not in a test function',
      },
      ['should return error if cursor is on line before test func definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 4, 1 },
        expected_err = 'cursor is not in a test function',
      },
      ['should return error if cursor is on char after test func definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            } ]],
        },
        cursor = { 7, 2 },
        expected_err = 'cursor is not in a test function',
      },
      ['should return error if cursor is on line after test func definition'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }
             ]],
        },
        cursor = { 8, 1 },
        expected_err = 'cursor is not in a test function',
      },
      ['should return error if func name does not start with Test'] = {
        tree = {
          ['foo_test.go'] = strings.dedent [[
            package foo_test

            import "testing"

            func Func(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 5, 1 },
        expected_err = 'cursor is not in a test function',
      },
    }

    for name, case in pairs(cases) do
      it(name, function()
        local root, teardown = temptree.create_temp_tree(case.tree)
        teardowns:add(teardown)
        vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])

        if case.cursor_range then
          for row = case.cursor_range.start_row, case.cursor_range.end_row do
            local cols = #vim.fn.getline(row)
            for col = 1, cols do
              vim.fn.cursor(row, col)

              local func_name, err = parsing.get_test_at_cursor()

              assert.are.equal(case.expected_name, func_name, 'incorrect test func name')
              assert.is_nil(err, 'expected no err')
            end
          end
        else
          vim.fn.cursor(case.cursor[1], case.cursor[2])

          local func_name, err = parsing.get_test_at_cursor()

          if case.expected_name then
            assert.are.equal(case.expected_name, func_name, 'incorrect name')
            assert.is_nil(err, 'expected no err')
          else
            assert.is_nil(func_name, 'expected no name')
            assert.are.equal(case.expected_err, err, 'incorrect err')
          end
        end
      end)
    end
  end)
end)

teardowns:teardown()
