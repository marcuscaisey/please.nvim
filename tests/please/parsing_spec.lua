local temptree = require('tests.utils.temptree')
local cursor = require('please.cursor')
local parsing = require('please.parsing')

describe('locate_build_target', function()
  local test_cases = {
    {
      name = 'should return location of a BUILD file in the root of the repo',
      tree = {
        '.plzconfig',
        BUILD = [[
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
          BUILD = [[
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
        ['BUILD.plz'] = [[
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
        ['BUILD.plz'] = [[
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
        BUILD = [[
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
        BUILD = [[
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
        BUILD = [[
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
        BUILD = [[
          export_file(
              name = "not_foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
      label = '//:foo',
      expected_position = { 1, 1 },
    },
  }

  for _, case in ipairs(test_cases) do
    it(case.name, function()
      local root, teardown_tree = temptree.create(case.tree)

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

      teardown_tree()
    end)
  end
end)

-- TODO: rework these tests so that they check every possible cursor position inside the test
describe('get_test_at_cursor', function()
  local run_test = function(case)
    local root, teardown_tree = temptree.create(case.tree)

    vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])
    cursor.set(case.cursor)

    local test, err = parsing.get_test_at_cursor()

    if case.expected_test then
      assert.are.same(case.expected_test, test, 'incorrect test')
    end

    if case.expected_err then
      assert.is_nil(test, 'expected no name')
      assert.are.equal(case.expected_err, err, 'incorrect err')
    else
      assert.is_nil(err, 'expected no err')
    end

    teardown_tree()
  end

  local run_tests = function(cases)
    for _, case in ipairs(cases) do
      it(case.name, function()
        run_test(case)
      end)
    end
  end

  describe('for go', function()
    run_tests({
      {
        name = 'should return test for func if cursor is inside test func definition',
        tree = {
          ['foo_test.go'] = [[
            func TestFunc(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 2, 4 },
        expected_test = { name = 'TestFunc', selector = '^TestFunc$' },
      },
      {
        name = 'should return error if func name does not start with Test',
        tree = {
          ['foo_test.go'] = [[
            func Func(t *testing.T) {
                t.Fatal("oh no")
            }]],
        },
        cursor = { 2, 1 },
        expected_err = 'cursor is not in a test function',
      },
      {
        name = 'should return error if func does not have a single *testing.T param',
        tree = {
          ['foo_test.go'] = [[
            func TestFunc() {
                fmt.Println("oh no")
            }]],
        },
        cursor = { 2, 1 },
        expected_err = 'cursor is not in a test function',
      },
      {
        name = 'should return test for method if cursor is inside testify suite test method definition',
        tree = {
          ['foo_test.go'] = [[
            func (s *fooSuite) TestMethod() {
                s.Fail("oh no")
            }]],
        },
        cursor = { 2, 4 },
        expected_test = { name = 'TestMethod', selector = '/^TestMethod$' },
      },
      {
        name = 'should return error if testify suite method name does not start with Test',
        tree = {
          ['foo_test.go'] = [[
            func (s *fooSuite) Method() {
                s.Fail("oh no")
            }]],
        },
        cursor = { 2, 1 },
        expected_err = 'cursor is not in a test function',
      },
    })
  end)

  describe('for python', function()
    run_tests({
      {
        name = 'should return test for method if cursor is inside unittest test method definition',
        tree = {
          ['foo_test.py'] = [[
            class TestFoo(unittest.TestCase):
                def test_method(self):
                    self.assertEqual(1, 2)
                ]],
        },
        cursor = { 3, 5 },
        expected_test = { name = 'TestFoo.test_method', selector = 'TestFoo.test_method' },
      },
      {
        name = 'should return error if unittest method name does not start with test_',
        tree = {
          ['foo_test.py'] = [[
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
          ['foo_test.py'] = [[
            class Foo:
                def test_method(self):
                    self.assertEqual(1, 2)
                ]],
        },
        cursor = { 3, 5 },
        expected_err = 'cursor is not in a test function',
      },
    })
  end)

  describe('should return test for func if cursor is inside test func definition', function()
    local tree = {
      ['foo_test.go'] = [[
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
        run_test({
          tree = tree,
          cursor = case.cursor,
          expected_test = { name = 'TestFunc', selector = '^TestFunc$' },
        })
      end)
    end
  end)

  describe('should return error if cursor is outside test func definition', function()
    local tree = {
      ['foo_test.go'] = [[

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
        run_test({
          tree = tree,
          cursor = case.cursor,
          expected_err = 'cursor is not in a test function',
        })
      end)
    end
  end)

  run_tests({
    {
      name = 'should return test if there are multiple test funcs in the file',
      tree = {
        ['foo_test.go'] = [[
            func TestFuncOne(t *testing.T) {
                t.Fatal("oh no")
            }

            func TestFuncTwo(t *testing.T) {
                t.Fatal("oh no")
            }]],
      },
      cursor = { 6, 4 },
      expected_test = { name = 'TestFuncTwo', selector = '^TestFuncTwo$' },
    },
    {
      name = 'should return error if language of file is not supported',
      tree = {
        ['hello.rb'] = 'puts "Hello, World!"',
      },
      cursor = { 1, 1 },
      expected_err = 'finding tests is not supported for ruby files',
    },
  })
end)

describe('list_tests_in_file', function()
  local run_test = function(case)
    local root, teardown_tree = temptree.create(case.tree)

    vim.cmd('edit ' .. root .. '/' .. vim.tbl_keys(case.tree)[1])

    local tests, err = parsing.list_tests_in_file()

    if case.expected_tests then
      assert.are.same(case.expected_tests, tests, 'incorrect tests')
    end

    if case.expected_err then
      assert.is_not_nil(err, 'expected error')
      assert.are.equal(case.expected_err, err, 'incorrect error')
      assert.is_nil(tests, 'expected no tests')
    else
      assert.is_nil(err, 'expected no error')
    end

    teardown_tree()
  end

  local run_tests = function(cases)
    for _, case in ipairs(cases) do
      it(case.name, function()
        run_test(case)
      end)
    end
  end

  describe('for go', function()
    run_tests({
      {
        name = 'should return test functions',
        tree = {
          ['foo.go'] = [[
            func TestFunction1(t *testing.T) {
                t.Fatal("oh no")
            }

            func TestFunction2(t *testing.T) {
                t.Fatal("oh no")
            }
          ]],
        },
        expected_tests = {
          { name = 'TestFunction1', selector = '^TestFunction1$' },
          { name = 'TestFunction2', selector = '^TestFunction2$' },
        },
      },
      {
        name = 'should return test function subtests',
        tree = {
          ['foo.go'] = [[
            func TestFunctionWithTableTests(t *testing.T) {
                testCases := []struct{
                    name  string
                    input int
                    want  int
                }{
                    {
                        name:  "TestNameInCamelCase",
                        input: 1,
                        want:  2,
                    },
                    {
                        name:  "test name in snake case",
                        input: 2,
                        want:  3,
                    },
                }

                for _, tc := range testCases {
                    t.Run(tc.name, func(t *testing.T) {
                        t.Fatal("oh no")
                    })
                }
            }

            func TestFunctionWithVarTableTests(t *testing.T) {
                var testCases = []struct{
                    name  string
                    input int
                    want  int
                }{
                    {
                        name:  "TestNameInCamelCase",
                        input: 1,
                        want:  2,
                    },
                    {
                        name:  "test name in snake case",
                        input: 2,
                        want:  3,
                    },
                }

                for _, tc := range testCases {
                    t.Run(tc.name, func(t *testing.T) {
                        t.Fatal("oh no")
                    })
                }
            }

            func TestFunctionWithEmptyTableTestCases(t *testing.T) {
                testCases := []struct{
                    name  string
                    input int
                    want  int
                }{}

                for _, tc := range testCases {
                    t.Run(tc.name, func(t *testing.T) {
                        t.Fatal("oh no")
                    })
                }
            }
          ]],
        },
        expected_tests = {
          { name = 'TestFunctionWithTableTests', selector = '^TestFunctionWithTableTests$' },
          {
            name = 'TestFunctionWithTableTests/TestNameInCamelCase',
            selector = '^TestFunctionWithTableTests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestFunctionWithTableTests/test_name_in_snake_case',
            selector = '^TestFunctionWithTableTests$/^test_name_in_snake_case$',
          },
          { name = 'TestFunctionWithVarTableTests', selector = '^TestFunctionWithVarTableTests$' },
          {
            name = 'TestFunctionWithVarTableTests/TestNameInCamelCase',
            selector = '^TestFunctionWithVarTableTests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestFunctionWithVarTableTests/test_name_in_snake_case',
            selector = '^TestFunctionWithVarTableTests$/^test_name_in_snake_case$',
          },
          { name = 'TestFunctionWithEmptyTableTestCases', selector = '^TestFunctionWithEmptyTableTestCases$' },
        },
      },
      {
        name = 'should return testify suite methods',
        tree = {
          ['foo.go'] = [[
            func (s *testSuite) TestSuiteMethod1() {
                s.FailNow("oh no")
            }

            func (s *testSuite) TestSuiteMethod2() {
                s.FailNow("oh no")
            }
          ]],
        },
        expected_tests = {
          { name = 'TestSuiteMethod1', selector = '/^TestSuiteMethod1$' },
          { name = 'TestSuiteMethod2', selector = '/^TestSuiteMethod2$' },
        },
      },
      {
        name = 'should return testify suite method subtests',
        tree = {
          ['foo.go'] = [[
            func (s *testSuite) TestSuiteMethodWithTableTests() {
                testCases := []struct {
                    name  string
                    input int
                    want  int
                }{
                    {
                        name:  "TestNameInCamelCase",
                        input: 1,
                        want:  2,
                    },
                    {
                        name:  "test name in snake case",
                        input: 2,
                        want:  3,
                    },
                }

                for _, tc := range testCases {
                    s.Run(tc.name, func() {
                        s.FailNow("oh no")
                    })
                }
            }

            func (s *testSuite) TestSuiteMethodWithVarTableTests() {
                var testCases = []struct {
                    name  string
                    input int
                    want  int
                }{
                  {
                      name:  "TestNameInCamelCase",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "test name in snake case",
                      input: 2,
                      want:  3,
                  },
                }

                for _, tc := range testCases {
                    s.Run(tc.name, func() {
                        s.FailNow("oh no")
                    })
                }
            }

            func (s *testSuite) TestSuiteMethodWithEmptyTableTestCases() {
                testCases := []struct {
                    name  string
                    input int
                    want  int
                }{}

                for _, tc := range testCases {
                    s.Run(tc.name, func() {
                        s.FailNow("oh no")
                    })
                }
            }
          ]],
        },
        expected_tests = {
          { name = 'TestSuiteMethodWithTableTests', selector = '/^TestSuiteMethodWithTableTests$' },
          {
            name = 'TestSuiteMethodWithTableTests/TestNameInCamelCase',
            selector = '/^TestSuiteMethodWithTableTests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestSuiteMethodWithTableTests/test_name_in_snake_case',
            selector = '/^TestSuiteMethodWithTableTests$/^test_name_in_snake_case$',
          },
          { name = 'TestSuiteMethodWithVarTableTests', selector = '/^TestSuiteMethodWithVarTableTests$' },
          {
            name = 'TestSuiteMethodWithVarTableTests/TestNameInCamelCase',
            selector = '/^TestSuiteMethodWithVarTableTests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestSuiteMethodWithVarTableTests/test_name_in_snake_case',
            selector = '/^TestSuiteMethodWithVarTableTests$/^test_name_in_snake_case$',
          },
          { name = 'TestSuiteMethodWithEmptyTableTestCases', selector = '/^TestSuiteMethodWithEmptyTableTestCases$' },
        },
      },
      {
        name = 'should return different types of tests',
        tree = {
          ['foo.go'] = [[
            func TestFunction(t *testing.T) {
                t.Fatal("oh no")
            }

            func TestFunctionWithSubtests(t *testing.T) {
                testCases := []struct{
                    name  string
                    input int
                    want  int
                }{
                    {
                        name:  "TestNameInCamelCase",
                        input: 1,
                        want:  2,
                    },
                    {
                        name:  "test name in snake case",
                        input: 2,
                        want:  3,
                    },
                }

                for _, tc := range testCases {
                    t.Run(tc.name, func(t *testing.T) {
                        t.Fatal("oh no")
                    })
                }
            }

            func (s *fooSuite) TestSuiteMethod() {
                s.FailNow("oh no")
            }

            func (s *testSuite) TestSuiteMethodWithTableTests() {
                testCases := []struct {
                    name  string
                    input int
                    want  int
                }{
                    {
                        name:  "TestNameInCamelCase",
                        input: 1,
                        want:  2,
                    },
                    {
                        name:  "test name in snake case",
                        input: 2,
                        want:  3,
                    },
                }

                for _, tc := range testCases {
                    s.Run(tc.name, func() {
                        s.FailNow("oh no")
                    })
                }
            }
          ]],
        },
        expected_tests = {
          { name = 'TestFunction', selector = '^TestFunction$' },
          { name = 'TestFunctionWithSubtests', selector = '^TestFunctionWithSubtests$' },
          {
            name = 'TestFunctionWithSubtests/TestNameInCamelCase',
            selector = '^TestFunctionWithSubtests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestFunctionWithSubtests/test_name_in_snake_case',
            selector = '^TestFunctionWithSubtests$/^test_name_in_snake_case$',
          },
          { name = 'TestSuiteMethod', selector = '/^TestSuiteMethod$' },
          { name = 'TestSuiteMethodWithTableTests', selector = '/^TestSuiteMethodWithTableTests$' },
          {
            name = 'TestSuiteMethodWithTableTests/TestNameInCamelCase',
            selector = '/^TestSuiteMethodWithTableTests$/^TestNameInCamelCase$',
          },
          {
            name = 'TestSuiteMethodWithTableTests/test_name_in_snake_case',
            selector = '/^TestSuiteMethodWithTableTests$/^test_name_in_snake_case$',
          },
        },
      },
    })
  end)

  describe('for python', function()
    run_tests({
      {
        name = 'should return unittest test methods',
        tree = {
          ['foo.py'] = [[
            class TestClass1(unittest.TestCase):
                def test_one(self):
                    self.fail("oh no")

            class TestClass2(unittest.TestCase):
                def test_one(self):
                    self.fail("oh no")

                def test_two(self):
                    self.fail("oh no")
          ]],
        },
        expected_tests = {
          { name = 'TestClass1.test_one', selector = 'TestClass1.test_one' },
          { name = 'TestClass2.test_one', selector = 'TestClass2.test_one' },
          { name = 'TestClass2.test_two', selector = 'TestClass2.test_two' },
        },
      },
    })
  end)

  it('should return error if language of file is not supported', function()
    run_test({
      tree = {
        ['hello.rb'] = 'puts "Hello, World!"',
      },
      expected_err = 'listing tests is not supported for ruby files',
    })
  end)

  it('should return error if file contains no tests', function()
    run_test({
      tree = {
        ['foo.go'] = [[
          func Func() {}
        ]],
      },
      expected_err = 'foo.go contains no tests',
    })
  end)
end)

describe('get_target_at_cursor', function()
  local run_test = function(case)
    local root, teardown_tree = temptree.create(case.tree)

    vim.cmd('edit ' .. root .. '/' .. case.file)
    cursor.set(case.cursor)

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

    teardown_tree()
  end

  describe('should return label and rule of target when cursor is inside build target definition', function()
    local tree = {
      BUILD = [[
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
        run_test({
          tree = tree,
          file = 'BUILD',
          cursor = case.cursor,
          expected_label = '//:foo',
          expected_rule = 'export_file',
        })
      end)
    end
  end)

  it('should return label of target in BUILD file in child dir of root', function()
    local tree = {
      ['pkg/'] = {
        BUILD = [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
      },
    }

    run_test({
      tree = tree,
      file = 'pkg/BUILD',
      cursor = { 2, 1 },
      expected_label = '//pkg:foo',
    })
  end)

  it('should return label and rule when there are multiple build targets in the BUILD file', function()
    run_test({
      tree = {
        BUILD = [[
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
    })
  end)

  describe('should return error when cursor is outside build target definition', function()
    local tree = {
      BUILD = [[

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
        run_test({
          tree = tree,
          file = 'BUILD',
          cursor = case.cursor,
          expected_err = 'cursor is not in a build target definition',
        })
      end)
    end
  end)

  it('should return label when rule uses single quotes', function()
    run_test({
      tree = {
        BUILD = [[
          export_file(
              name = 'foo',
              # src = 'foo2.txt',
          )]],
      },
      file = 'BUILD',
      cursor = { 1, 1 },
      expected_label = '//:foo',
    })
  end)
end)
