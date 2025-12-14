local temptree = require('tests.temptree')
local parsing = require('please.parsing')

describe('locate_build_target', function()
  local test_cases = {
    {
      name = 'should return location of target in the root of the repo',
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
      expected_file = 'BUILD',
      expected_position = { 1, 0 },
    },
    {
      name = 'should return location of target in a child dir of the repo',
      tree = {
        '.plzconfig',
        ['foo/'] = {
          BUILD = [[
          export_file(
              name = "bar",
              src = "foo.txt",
          )]],
          'bar.txt',
        },
      },
      label = '//foo:bar',
      expected_file = 'foo/BUILD',
      expected_position = { 1, 0 },
    },
    {
      name = 'should return location of target in a BUILD.plz file',
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
      expected_file = 'BUILD.plz',
      expected_position = { 1, 0 },
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
      expected_file = 'BUILD.plz',
      expected_position = { 1, 0 },
    },
    {
      name = 'should return location of target at the start of a BUILD file',
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
    },
    {
      name = 'should return location of target in the middle of a BUILD file',
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
      expected_position = { 6, 0 },
    },
    {
      name = 'should return location of target which is indented',
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
      expected_position = { 1, 2 },
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
      expected_position = { 1, 0 },
    },
    {
      name = 'should return location of target with shortened label',
      tree = {
        '.plzconfig',
        ['bar/'] = {
          BUILD = [[
            export_file(
                name = "foo",
                src = "foo.txt",
            )

            export_file(
                name = "bar",
                src = "bar.txt",
            )
          ]],
          'foo.txt',
          'bar.txt',
        },
      },
      label = '//bar',
      expected_file = 'bar/BUILD',
      expected_position = { 6, 0 },
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
      name = 'should return error if label is not a valid',
      tree = { '.plzconfig' },
      label = 'foo',
      expected_err = '"foo" is not a valid build label',
    },
  }

  for _, case in ipairs(test_cases) do
    it(case.name, function()
      local root = temptree.create(case.tree)

      local target, err = parsing.locate_build_target(root, case.label)

      if case.expected_file then
        assert.equal(root .. '/' .. case.expected_file, target and target.file, 'incorrect file')
        assert.same(case.expected_position, target and target.position, 'incorrect position')
      end

      if case.expected_err then
        assert.equal(case.expected_err, err, 'incorrect error')
        assert.is_nil(target, 'expected no target')
      else
        assert.is_nil(err, 'expected no error')
      end
    end)
  end
end)

describe('get_test_at_cursor', function()
  ---@alias test_case {name:string, filetype:string, file:string, cursor_position:integer[], expected_test:{name:string, selector:string}}
  ---@param test_cases test_case[]
  local function run_tests(test_cases)
    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        local root = temptree.create({
          ['test_file'] = tc.file,
        })

        vim.cmd('edit ' .. root .. '/test_file')
        vim.api.nvim_set_option_value('filetype', tc.filetype, { buf = 0 })
        vim.api.nvim_win_set_cursor(0, tc.cursor_position)

        local test, err = parsing.get_test_at_cursor()

        assert.is_nil(err, 'expected no error to be returned')
        assert.same(tc.expected_test, test, 'incorrect test returned')
      end)
    end
  end

  describe('returns Go test -', function()
    local test_cases = {
      {
        name = 'test function',
        filetype = 'go',
        file = [[
          func TestFunction1(t *testing.T) {
              t.Fatal("oh no")
          }

          func TestFunction2(t *testing.T) {
              t.Fatal("oh no")
          }
        ]], -- go
        cursor_position = { 2, 4 }, -- inside TestFunction1
        expected_test = {
          name = 'TestFunction1',
          selector = '^TestFunction1$',
        },
      },
      {
        name = 'test function with subtests - pascal case name',
        filetype = 'go',
        file = [[
          func TestFunctionWithSubtests(t *testing.T) {
              t.Run("PascalCaseName", func(t *testing.T) {
                  t.Fatal("oh no")
              })

              t.Run("snake case name", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]], -- go
        cursor_position = { 3, 8 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestFunctionWithSubtests/PascalCaseName',
          selector = '^TestFunctionWithSubtests$/^PascalCaseName$',
        },
      },
      {
        name = 'test function with subtests - snake case name',
        filetype = 'go',
        file = [[
          func TestFunctionWithSubtests(t *testing.T) {
              t.Run("PascalCaseName", func(t *testing.T) {
                  t.Fatal("oh no")
              })

              t.Run("snake case name", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]], -- go
        cursor_position = { 7, 8 }, -- inside snake case name
        expected_test = {
          name = 'TestFunctionWithSubtests/snake_case_name',
          selector = '^TestFunctionWithSubtests$/^snake_case_name$',
        },
      },
      {
        name = 'test function with nested subtests',
        filetype = 'go',
        file = [[
          func TestFunctionWithNestedSubtests(t *testing.T) {
              t.Run("Subtest", func(t *testing.T) {
                  t.Run("NestedSubtest1", func(t *testing.T) {
                      t.Fatal("oh no")
                  })

                  t.Run("NestedSubtest2", func(t *testing.T) {
                      t.Fatal("oh no")
                  })
              })
          }
        ]], -- go
        cursor_position = { 4, 12 }, -- inside NestedSubtest1
        expected_test = {
          name = 'TestFunctionWithNestedSubtests/Subtest/NestedSubtest1',
          selector = '^TestFunctionWithNestedSubtests$/^Subtest$/^NestedSubtest1$',
        },
      },
      {
        name = 'test function with table tests - cursor inside test case - pascal case name',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTests(t *testing.T) {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
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
        ]], -- go
        cursor_position = { 8, 12 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestFunctionWithTableTests/PascalCaseName',
          selector = '^TestFunctionWithTableTests$/^PascalCaseName$',
        },
      },
      {
        name = 'test function with table tests - cursor inside test case - snake case name',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTests(t *testing.T) {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
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
        ]], -- go
        cursor_position = { 13, 12 }, -- inside snake case name
        expected_test = {
          name = 'TestFunctionWithTableTests/snake_case_name',
          selector = '^TestFunctionWithTableTests$/^snake_case_name$',
        },
      },
      {
        name = 'test function with table tests - cursor inside t.Run',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTests(t *testing.T) {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
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
        ]], -- go
        cursor_position = { 21, 12 }, -- inside t.Run
        expected_test = {
          name = 'TestFunctionWithTableTests',
          selector = '^TestFunctionWithTableTests$',
        },
      },
      {
        name = 'test function with table tests - test cases defined with var',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTestsVar(t *testing.T) {
              var testCases = []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
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
        ]], -- go
        cursor_position = { 8, 12 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestFunctionWithTableTestsVar/PascalCaseName',
          selector = '^TestFunctionWithTableTestsVar$/^PascalCaseName$',
        },
      },
      {
        name = 'test function with table tests - empty test cases',
        filetype = 'go',
        file = [[
          func TestFunctionWithEmptyTableTestCases(t *testing.T) {
              testCases := []struct {
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
        ]], -- go
        cursor_position = { 10, 12 }, -- inside t.Run
        expected_test = {
          name = 'TestFunctionWithEmptyTableTestCases',
          selector = '^TestFunctionWithEmptyTableTestCases$',
        },
      },
      {
        name = 'test function with subtests nested inside table test - cursor inside test case',
        filetype = 'go',
        file = [[
          func TestFunctionWithSubtestsNestedInsideTableTest(t *testing.T) {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "TestCase1",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "TestCase2",
                      input: 1,
                      want:  2,
                  },
              }

              for _, tc := range testCases {
                  t.Run(tc.name, func(t *testing.T) {
                      t.Run("Subtest1", func(t *testing.T) {
                          t.Fatal("oh no")
                      })

                      t.Run("Subtest2", func(t *testing.T) {
                          t.Fatal("oh no")
                      })
                  })
              }
          }
        ]], -- go
        cursor_position = { 8, 12 }, -- inside TestCase1
        expected_test = {
          name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase1',
          selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase1$',
        },
      },
      {
        name = 'test function with subtests nested inside table test - cursor inside subtest',
        filetype = 'go',
        file = [[
          func TestFunctionWithSubtestsNestedInsideTableTest(t *testing.T) {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "TestCase1",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "TestCase2",
                      input: 1,
                      want:  2,
                  },
              }

              for _, tc := range testCases {
                  t.Run(tc.name, func(t *testing.T) {
                      t.Run("Subtest1", func(t *testing.T) {
                          t.Fatal("oh no")
                      })

                      t.Run("Subtest2", func(t *testing.T) {
                          t.Fatal("oh no")
                      })
                  })
              }
          }
        ]], -- go
        cursor_position = { 22, 16 }, -- inside Subtest1
        expected_test = {
          name = 'TestFunctionWithSubtestsNestedInsideTableTest',
          selector = '^TestFunctionWithSubtestsNestedInsideTableTest$',
        },
      },
      {
        name = 'test function with table tests nested inside subtest - cursor inside test case',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTestsNestedInsideSubtest(t *testing.T) {
              t.Run("Subtest1", func(t *testing.T) {
                  testCases := []struct {
                      name  string
                      input int
                      want  int
                  }{
                      {
                          name:  "TestCase1",
                          input: 1,
                          want:  2,
                      },
                      {
                          name:  "TestCase2",
                          input: 1,
                          want:  2,
                      },
                  }

                  for _, tc := range testCases {
                      t.Run(tc.name, func(t *testing.T) {
                          t.Fatal("oh no")
                      })
                  }
              })

              t.Run("Subtest2", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]], -- go
        cursor_position = { 9, 16 }, -- inside TestCase1
        expected_test = {
          name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1/TestCase1',
          selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$/^TestCase1$',
        },
      },
      {
        name = 'test function with table tests nested inside subtest - cursor inside t.Run',
        filetype = 'go',
        file = [[
          func TestFunctionWithTableTestsNestedInsideSubtest(t *testing.T) {
              t.Run("Subtest1", func(t *testing.T) {
                  testCases := []struct {
                      name  string
                      input int
                      want  int
                  }{
                      {
                          name:  "TestCase1",
                          input: 1,
                          want:  2,
                      },
                      {
                          name:  "TestCase2",
                          input: 1,
                          want:  2,
                      },
                  }

                  for _, tc := range testCases {
                      t.Run(tc.name, func(t *testing.T) {
                          t.Fatal("oh no")
                      })
                  }
              })

              t.Run("Subtest2", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]], -- go
        cursor_position = { 22, 16 }, -- inside t.Run
        expected_test = {
          name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1',
          selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$',
        },
      },
      {
        name = 'testify suite method',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethod1() {
              s.Fail("oh no")
          }

          func (s *testSuiteWithEmbeddedPointer) TestMethod2() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 2, 4 }, -- inside TestMethod1
        expected_test = {
          name = 'TestMethod1',
          selector = '/^TestMethod1$',
        },
      },
      {
        name = 'testify suite method with suite name - struct literal',
        filetype = 'go',
        file = [[
          func TestSuite(t *testing.T) {
              suite.Run(t, &testSuite{})
          }

          func (s *testSuite) TestMethod1() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 6, 4 }, -- inside TestMethod1
        expected_test = {
          name = 'TestSuite/TestMethod1',
          selector = '^TestSuite$/^TestMethod1$',
        },
      },
      {
        name = 'testify suite method with suite name - embedded pointer',
        filetype = 'go',
        file = [[
          func TestSuiteWithEmbeddedPointer(t *testing.T) {
              suite.Run(t, &testSuiteWithEmbeddedPointer{
                  Suite: &suite.Suite{},
              })
          }

          func (s *testSuiteWithEmbeddedPointer) TestMethod2() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 8, 4 }, -- inside TestMethod2
        expected_test = {
          name = 'TestSuiteWithEmbeddedPointer/TestMethod2',
          selector = '^TestSuiteWithEmbeddedPointer$/^TestMethod2$',
        },
      },
      {
        name = 'testify suite method with suite name - new',
        filetype = 'go',
        file = [[
          func TestSuiteWithNew(t *testing.T) {
              suite.Run(t, new(testSuiteWithNew))
          }

          func (s *testSuiteWithNew) TestMethod3() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 6, 4 }, -- inside TestMethod3
        expected_test = {
          name = 'TestSuiteWithNew/TestMethod3',
          selector = '^TestSuiteWithNew$/^TestMethod3$',
        },
      },
      {
        name = 'testify suite method with suite name - value receiver type',
        filetype = 'go',
        file = [[
          func TestSuite(t *testing.T) {
              suite.Run(t, &testSuite{})
          }

          func (s testSuite) TestMethod5() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 6, 4 }, -- inside TestMethod5
        expected_test = {
          name = 'TestSuite/TestMethod5',
          selector = '^TestSuite$/^TestMethod5$',
        },
      },
      {
        name = 'testify suite method with suite name - multiple runs',
        filetype = 'go',
        file = [[
          func TestSuiteMultipleRuns1(t *testing.T) {
              suite.Run(t, &testSuiteMultipleRuns{})
          }

          func TestSuiteMultipleRuns2(t *testing.T) {
              suite.Run(t, &testSuiteMultipleRuns{})
          }

          func (s *testSuiteMultipleRuns) TestMethod6() {
              s.Fail("oh no")
          }
        ]], -- go
        cursor_position = { 10, 4 }, -- inside TestMethod6
        expected_test = {
          name = 'TestMethod6',
          selector = '/^TestMethod6$',
        },
      },
      {
        name = 'testify suite method with subtests - pascal case name',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithSubtests() {
              s.Run("PascalCaseName", func() {
                  s.Fail("oh no")
              })

              s.Run("snake case name", func() {
                  s.Fail("oh no")
              })
          }
        ]], -- go
        cursor_position = { 3, 8 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestMethodWithSubtests/PascalCaseName',
          selector = '/^TestMethodWithSubtests$/^PascalCaseName$',
        },
      },
      {
        name = 'testify suite method with subtests - snake case name',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithSubtests() {
              s.Run("PascalCaseName", func() {
                  s.Fail("oh no")
              })

              s.Run("snake case name", func() {
                  s.Fail("oh no")
              })
          }
        ]], -- go
        cursor_position = { 7, 8 }, -- inside snake case name
        expected_test = {
          name = 'TestMethodWithSubtests/snake_case_name',
          selector = '/^TestMethodWithSubtests$/^snake_case_name$',
        },
      },
      {
        name = 'testify suite method with nested subtests',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithNestedSubtests() {
              s.Run("Subtest", func() {
                  s.Run("NestedSubtest1", func() {
                      s.Fail("oh no")
                  })

                  s.Run("NestedSubtest2", func() {
                      s.Fail("oh no")
                  })
              })
          }
        ]], -- go
        cursor_position = { 4, 12 }, -- inside NestedSubtest1
        expected_test = {
          name = 'TestMethodWithNestedSubtests/Subtest/NestedSubtest1',
          selector = '/^TestMethodWithNestedSubtests$/^Subtest$/^NestedSubtest1$',
        },
      },
      {
        name = 'testify suite method with table tests - cursor inside test case - pascal case name',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithTableTests() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
                      input: 2,
                      want:  3,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Fail("oh no")
                  })
              }
          }
        ]], -- go
        cursor_position = { 8, 12 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestMethodWithTableTests/PascalCaseName',
          selector = '/^TestMethodWithTableTests$/^PascalCaseName$',
        },
      },
      {
        name = 'testify suite method with table tests - cursor inside test case - snake case name',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithTableTests() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
                      input: 2,
                      want:  3,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Fail("oh no")
                  })
              }
          }
        ]], -- go
        cursor_position = { 13, 12 }, -- inside snake case name
        expected_test = {
          name = 'TestMethodWithTableTests/snake_case_name',
          selector = '/^TestMethodWithTableTests$/^snake_case_name$',
        },
      },
      {
        name = 'testify suite method with table tests - cursor inside t.Run',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithTableTests() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
                      input: 2,
                      want:  3,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Fail("oh no")
                  })
              }
          }
        ]], -- go
        cursor_position = { 21, 12 }, -- inside t.Run
        expected_test = {
          name = 'TestMethodWithTableTests',
          selector = '/^TestMethodWithTableTests$',
        },
      },
      {
        name = 'testify suite method with table tests - test cases defined with var',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithVarTableTests() {
              var testCases = []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "PascalCaseName",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "snake case name",
                      input: 2,
                      want:  3,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Fail("oh no")
                  })
              }
          }
        ]], -- go
        cursor_position = { 8, 12 }, -- inside PascalCaseName
        expected_test = {
          name = 'TestMethodWithVarTableTests/PascalCaseName',
          selector = '/^TestMethodWithVarTableTests$/^PascalCaseName$',
        },
      },
      {
        name = 'testify suite method with table tests - empty test cases',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithEmptyTableTestCases() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{}

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Fail("oh no")
                  })
              }
          }
        ]], -- go
        cursor_position = { 10, 12 }, -- inside t.Run
        expected_test = {
          name = 'TestMethodWithEmptyTableTestCases',
          selector = '/^TestMethodWithEmptyTableTestCases$',
        },
      },
      {
        name = 'testify suite method with subtests nested inside table test - cursor inside test case',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithSubtestsNestedInsideTableTest() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "TestCase1",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "TestCase2",
                      input: 1,
                      want:  2,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Run("Subtest1", func() {
                          s.Fail("oh no")
                      })

                      s.Run("Subtest2", func() {
                          s.Fail("oh no")
                      })
                  })
              }
          }
        ]], -- go
        cursor_position = { 8, 12 }, -- inside TestCase1
        expected_test = {
          name = 'TestMethodWithSubtestsNestedInsideTableTest/TestCase1',
          selector = '/^TestMethodWithSubtestsNestedInsideTableTest$/^TestCase1$',
        },
      },
      {
        name = 'testify suite method with subtests nested inside table test - cursor inside subtest',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithSubtestsNestedInsideTableTest() {
              testCases := []struct {
                  name  string
                  input int
                  want  int
              }{
                  {
                      name:  "TestCase1",
                      input: 1,
                      want:  2,
                  },
                  {
                      name:  "TestCase2",
                      input: 1,
                      want:  2,
                  },
              }

              for _, tc := range testCases {
                  s.Run(tc.name, func() {
                      s.Run("Subtest1", func() {
                          s.Fail("oh no")
                      })

                      s.Run("Subtest2", func() {
                          s.Fail("oh no")
                      })
                  })
              }
          }
        ]], -- go
        cursor_position = { 22, 16 }, -- inside Subtest1
        expected_test = {
          name = 'TestMethodWithSubtestsNestedInsideTableTest',
          selector = '/^TestMethodWithSubtestsNestedInsideTableTest$',
        },
      },
      {
        name = 'testify suite method with table tests nested inside subtest - cursor inside test case',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithTableTestsNestedInsideSubtest() {
              s.Run("Subtest1", func() {
                  testCases := []struct {
                      name  string
                      input int
                      want  int
                  }{
                      {
                          name:  "TestCase1",
                          input: 1,
                          want:  2,
                      },
                      {
                          name:  "TestCase2",
                          input: 1,
                          want:  2,
                      },
                  }

                  for _, tc := range testCases {
                      s.Run(tc.name, func() {
                          s.Fail("oh no")
                      })
                  }
              })

              s.Run("Subtest2", func() {
                  s.Fail("oh no")
              })
          }
        ]], -- go
        cursor_position = { 9, 16 }, -- inside TestCase1
        expected_test = {
          name = 'TestMethodWithTableTestsNestedInsideSubtest/Subtest1/TestCase1',
          selector = '/^TestMethodWithTableTestsNestedInsideSubtest$/^Subtest1$/^TestCase1$',
        },
      },
      {
        name = 'testify suite method with table tests nested inside subtest - cursor inside t.Run',
        filetype = 'go',
        file = [[
          func (s *testSuite) TestMethodWithTableTestsNestedInsideSubtest() {
              s.Run("Subtest1", func() {
                  testCases := []struct {
                      name  string
                      input int
                      want  int
                  }{
                      {
                          name:  "TestCase1",
                          input: 1,
                          want:  2,
                      },
                      {
                          name:  "TestCase2",
                          input: 1,
                          want:  2,
                      },
                  }

                  for _, tc := range testCases {
                      s.Run(tc.name, func() {
                          s.Fail("oh no")
                      })
                  }
              })

              s.Run("Subtest2", func() {
                  s.Fail("oh no")
              })
          }
        ]], -- go
        cursor_position = { 22, 16 }, -- inside t.Run
        expected_test = {
          name = 'TestMethodWithTableTestsNestedInsideSubtest/Subtest1',
          selector = '/^TestMethodWithTableTestsNestedInsideSubtest$/^Subtest1$',
        },
      },
    }

    run_tests(test_cases)
  end)

  describe('returns Python test -', function()
    local test_cases = { ---@type test_case[]
      {
        name = 'unittest test method',
        filetype = 'python',
        file = [[
          class TestCase(unittest.TestCase):

              def test_method_1(self):
                  self.fail("oh no")

              def test_method_2(self):
                  self.fail("oh no")
        ]], -- python
        cursor_position = { 4, 8 }, -- inside test_method_1
        expected_test = {
          name = 'TestCase.test_method_1',
          selector = 'TestCase.test_method_1',
        },
      },
      {
        name = 'unittest test method - decorator',
        filetype = 'python',
        file = [[
          class TestCase(unittest.TestCase):

              def test_method_2(self):
                  self.fail("oh no")

              @decorator
              def test_method_with_decorator(self):
                  self.fail("oh no")
        ]], -- python
        cursor_position = { 8, 8 }, -- inside test_method_with_decorator
        expected_test = {
          name = 'TestCase.test_method_with_decorator',
          selector = 'TestCase.test_method_with_decorator',
        },
      },
      {
        name = 'unittest test method - decorator with params',
        filetype = 'python',
        file = [[
          class TestCase(unittest.TestCase):

              def test_method_2(self):
                  self.fail("oh no")

              @decorator_with_params(2)
              def test_method_with_decorator_with_params(self):
                  self.fail("oh no")
        ]], -- python
        cursor_position = { 8, 8 }, -- inside test_method_with_decorator_with_params
        expected_test = {
          name = 'TestCase.test_method_with_decorator_with_params',
          selector = 'TestCase.test_method_with_decorator_with_params',
        },
      },
    }

    run_tests(test_cases)
  end)

  it('returns error if language of file is not supported', function()
    local root = temptree.create({
      ['hello.rb'] = 'puts "Hello, World!"', -- ruby
    })

    vim.cmd('edit ' .. root .. '/hello.rb')

    local tests, err = parsing.get_test_at_cursor()

    assert.equal(err, 'finding tests is not supported for ruby files')
    assert.is_nil(tests, 'expected no tests to be returned')
  end)

  it('returns error if cursor is not in a test', function()
    local root = temptree.create({
      ['foo_test.go'] = [[
        func Func() {
            fmt.Println("foo")
        }
      ]], -- go
    })

    vim.cmd('edit ' .. root .. '/' .. 'foo_test.go')
    vim.api.nvim_win_set_cursor(0, { 2, 4 })

    local tests, err = parsing.get_test_at_cursor()

    assert.equal(err, 'cursor is not in a test')
    assert.is_nil(tests, 'expected no tests to be returned')
  end)
end)

describe('get_target_at_cursor', function()
  local function run_test(case)
    local root = temptree.create(case.tree)

    vim.cmd('edit ' .. root .. '/' .. case.file)
    vim.api.nvim_win_set_cursor(0, case.cursor_position)

    local target, err = parsing.get_target_at_cursor(root)

    if case.expected_label then
      assert.equal(case.expected_label, target and target.label, 'incorrect label')
    end
    if case.expected_rule then
      assert.equal(case.expected_rule, target and target.rule, 'incorrect rule')
    end

    if case.expected_err then
      assert.is_not_nil(err, 'expected error')
      assert.equal(case.expected_err, err, 'incorrect error')
      assert.is_nil(target, 'expected no target')
    else
      assert.is_nil(err, 'expected no error')
    end
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
        cursor_position = { 1, 0 },
      },
      {
        name = 'middle row',
        cursor_position = { 2, 0 },
      },
      {
        name = 'last char',
        cursor_position = { 4, 0 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test({
          tree = tree,
          file = 'BUILD',
          cursor_position = case.cursor_position,
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
      cursor_position = { 2, 0 },
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
      cursor_position = { 7, 3 },
      expected_label = '//:foo2',
      expected_rule = 'export_file',
    })
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
      cursor_position = { 1, 0 },
      expected_label = '//:foo',
    })
  end)

  it('should return shortened label when target name matches directory', function()
    run_test({
      tree = {
        '.plzconfig',
        ['bar/'] = {
          BUILD = [[
            export_file(
                name = "foo",
                src = "foo.txt",
            )

            export_file(
                name = "bar",
                src = "bar.txt",
            )
          ]],
          'foo.txt',
          'bar.txt',
        },
      },
      file = 'bar/BUILD',
      cursor_position = { 6, 0 },
      expected_label = '//bar',
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
        cursor_position = { 1, 0 },
      },
      {
        name = 'before first char',
        cursor_position = { 2, 0 },
      },
      {
        name = 'after last char',
        cursor_position = { 5, 1 },
      },
      {
        name = 'after last row',
        cursor_position = { 6, 0 },
      },
    }

    for _, case in ipairs(test_cases) do
      it('- ' .. case.name, function()
        run_test({
          tree = tree,
          file = 'BUILD',
          cursor_position = case.cursor_position,
          expected_err = 'cursor is not in a build target definition',
        })
      end)
    end
  end)
end)

describe('get_label_at_cursor', function()
  ---@class TestCase
  ---@field name string
  ---@field file string
  ---@field position integer[]
  ---@field expected_cursor_value string
  ---@field expected_label string?

  ---@param test_case TestCase
  local function run_test(test_case)
    local root = temptree.create({
      file = test_case.file,
    })

    vim.cmd.edit(vim.fs.joinpath(root, 'file'))
    vim.api.nvim_win_set_cursor(0, test_case.position)

    if test_case.expected_cursor_value then
      local actual_cursor_value = vim.api.nvim_buf_get_text(
        0,
        test_case.position[1] - 1,
        test_case.position[2],
        test_case.position[1] - 1,
        test_case.position[2] + 1,
        {}
      )[1]
      assert.equal(test_case.expected_cursor_value, actual_cursor_value, 'incorrect cursor value')
    end

    local actual_label = parsing.get_label_at_cursor()

    if test_case.expected_label then
      assert.equal(test_case.expected_label, actual_label, 'incorrect label')
    else
      assert.is_nil(actual_label, 'expected no label')
    end
  end

  ---@type TestCase[]
  local test_cases = {
    {
      name = 'no label returned when cursor on line before label',
      file = [[
        line before
        ^
        before //foo/bar:baz after
        line after
      ]],
      position = { 1, 0 },
      expected_cursor_value = 'l',
      expected_label = nil,
    },
    {
      name = 'no label returned when cursor just before label',
      file = [[
        line before
        before //foo/bar:baz after
              ^
        line after
      ]],
      position = { 2, 6 },
      expected_cursor_value = ' ',
      expected_label = nil,
    },
    {
      name = 'label returned when cursor at start of label',
      file = [[
        line before
        before //foo/bar:baz after
               ^
        line after
      ]],
      position = { 2, 7 },
      expected_cursor_value = '/',
      expected_label = '//foo/bar:baz',
    },
    {
      name = 'label returned when cursor in middle of label',
      file = [[
        line before
        before //foo/bar:baz after
                       ^
        line after
      ]],
      position = { 2, 15 },
      expected_cursor_value = 'r',
      expected_label = '//foo/bar:baz',
    },
    {
      name = 'label returned when cursor at end of label',
      file = [[
        line before
        before //foo/bar:baz after
                           ^
        line after
      ]],
      position = { 2, 19 },
      expected_cursor_value = 'z',
      expected_label = '//foo/bar:baz',
    },
    {
      name = 'no label returned when cursor just after label',
      file = [[
        line before
        before //foo/bar:baz after
                            ^
        line after
      ]],
      position = { 2, 20 },
      expected_cursor_value = ' ',
      expected_label = nil,
    },
    {
      name = 'no label returned when cursor on line after label',
      file = [[
        line before
        before //foo/bar:baz after
        line after
        ^
      ]],
      position = { 3, 0 },
      expected_cursor_value = 'l',
      expected_label = nil,
    },
    {
      name = 'label returned when cursor on first of three labels',
      file = '//a/b:c //d/e:f //g/h:i',
      position = { 1, 2 },
      expected_cursor_value = 'a',
      expected_label = '//a/b:c',
    },
    {
      name = 'label returned when cursor on second of three labels',
      file = '//a/b:c //d/e:f //g/h:i',
      position = { 1, 10 },
      expected_cursor_value = 'd',
      expected_label = '//d/e:f',
    },
    {
      name = 'label returned when cursor on third of three labels',
      file = '//a/b:c //d/e:f //g/h:i',
      position = { 1, 18 },
      expected_cursor_value = 'g',
      expected_label = '//g/h:i',
    },
    {
      name = 'label returned when label has no package',
      file = '//:foo',
      position = { 1, 2 },
      expected_cursor_value = ':',
      expected_label = '//:foo',
    },
    {
      name = 'label returned when label has one directory in package',
      file = '//foo:bar',
      position = { 1, 5 },
      expected_cursor_value = ':',
      expected_label = '//foo:bar',
    },
    {
      name = 'label returned when label is shortened',
      file = '//foo',
      position = { 1, 2 },
      expected_cursor_value = 'f',
      expected_label = '//foo',
    },
  }

  for _, test_case in ipairs(test_cases) do
    it('- ' .. test_case.name, function()
      run_test(test_case)
    end)
  end
end)
