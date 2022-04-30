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
  local run_tests = function(cases)
    for _, case in pairs(cases) do
      it(case.name, function()
        local root, teardown = temptree.create_temp_tree(case.tree)
        teardowns:add(teardown)
        vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])

        vim.fn.cursor(case.cursor[1], case.cursor[2])

        if case.expected_name then
          local func_name, err = parsing.get_test_at_cursor()
          assert.are.equal(case.expected_name, func_name, 'incorrect name')
          assert.is_nil(err, 'expected no err')
        elseif case.raises_error then
          assert.has_error(function()
            parsing.get_test_at_cursor()
          end, case.expected_err)
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
        cursor = { 5, 1 },
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

teardowns:teardown()
