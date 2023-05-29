local cursor = require('please.cursor')
local parsingv2 = require('please.parsingv2')
local temptree = require('tests.utils.temptree')

describe('list_tests_at_cursor', function()
  describe('returns Go tests -', function()
    local test_cases = {
      {
        name = 'test function',
        file = [[
          func TestFunction1(t *testing.T) {
              t.Fatal("oh no")
          }

          func TestFunction2(t *testing.T) {
              t.Fatal("oh no")
          }
        ]],                            -- go
        cursor = { row = 2, col = 5 }, -- inside TestFunction1
        expected_tests = {
          {
            name = 'TestFunction1',
            selector = '^TestFunction1$',
          },
        },
      },
      {
        name = 'test function with subtests - pascal case name',
        file = [[
          func TestFunctionWithSubtests(t *testing.T) {
              t.Run("PascalCaseName", func(t *testing.T) {
                  t.Fatal("oh no")
              })

              t.Run("snake case name", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]],                            -- go
        cursor = { row = 3, col = 9 }, -- inside PascalCaseName
        expected_tests = {
          {
            name = 'TestFunctionWithSubtests',
            selector = '^TestFunctionWithSubtests$',
          },
          {
            name = 'TestFunctionWithSubtests/PascalCaseName',
            selector = '^TestFunctionWithSubtests$/^PascalCaseName$',
          },
        },
      },
      {
        name = 'test function with subtests - snake case name',
        file = [[
          func TestFunctionWithSubtests(t *testing.T) {
              t.Run("PascalCaseName", func(t *testing.T) {
                  t.Fatal("oh no")
              })

              t.Run("snake case name", func(t *testing.T) {
                  t.Fatal("oh no")
              })
          }
        ]],                            -- go
        cursor = { row = 7, col = 9 }, -- inside snake case name
        expected_tests = {
          {
            name = 'TestFunctionWithSubtests',
            selector = '^TestFunctionWithSubtests$',
          },
          {
            name = 'TestFunctionWithSubtests/snake_case_name',
            selector = '^TestFunctionWithSubtests$/^snake_case_name$',
          },
        },
      },
      {
        name = 'test function with nested subtests',
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
        ]],                             -- go
        cursor = { row = 4, col = 13 }, -- inside NestedSubtest1
        expected_tests = {
          {
            name = 'TestFunctionWithNestedSubtests',
            selector = '^TestFunctionWithNestedSubtests$',
          },
          {
            name = 'TestFunctionWithNestedSubtests/Subtest',
            selector = '^TestFunctionWithNestedSubtests$/^Subtest$',
          },
          {
            name = 'TestFunctionWithNestedSubtests/Subtest/NestedSubtest1',
            selector = '^TestFunctionWithNestedSubtests$/^Subtest$/^NestedSubtest1$',
          },
        },
      },
      {
        name = 'test function with table tests - cursor inside test case - pascal case name',
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
        ]],                             -- go
        cursor = { row = 8, col = 13 }, -- inside PascalCaseName
        expected_tests = {
          {
            name = 'TestFunctionWithTableTests',
            selector = '^TestFunctionWithTableTests$',
          },
          {
            name = 'TestFunctionWithTableTests/PascalCaseName',
            selector = '^TestFunctionWithTableTests$/^PascalCaseName$',
          },
        },
      },
      {
        name = 'test function with table tests - cursor inside test case - snake case name',
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
        ]],                              -- go
        cursor = { row = 13, col = 13 }, -- inside snake case name
        expected_tests = {
          {
            name = 'TestFunctionWithTableTests',
            selector = '^TestFunctionWithTableTests$',
          },
          {
            name = 'TestFunctionWithTableTests/snake_case_name',
            selector = '^TestFunctionWithTableTests$/^snake_case_name$',
          },
        },
      },
      {
        name = 'test function with table tests - cursor inside t.Run',
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
        ]],                              -- go
        cursor = { row = 21, col = 13 }, -- inside t.Run
        expected_tests = {
          {
            name = 'TestFunctionWithTableTests',
            selector = '^TestFunctionWithTableTests$',
          },
          {
            name = 'TestFunctionWithTableTests/PascalCaseName',
            selector = '^TestFunctionWithTableTests$/^PascalCaseName$',
          },
          {
            name = 'TestFunctionWithTableTests/snake_case_name',
            selector = '^TestFunctionWithTableTests$/^snake_case_name$',
          },
        },
      },
      {
        name = 'test function with table tests - test cases defined with var',
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
        ]],                             -- go
        cursor = { row = 8, col = 13 }, -- inside PascalCaseName
        expected_tests = {
          {
            name = 'TestFunctionWithTableTestsVar',
            selector = '^TestFunctionWithTableTestsVar$',
          },
          {
            name = 'TestFunctionWithTableTestsVar/PascalCaseName',
            selector = '^TestFunctionWithTableTestsVar$/^PascalCaseName$',
          },
        },
      },
      {
        name = 'test function with table tests - empty test cases',
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
        ]],                              -- go
        cursor = { row = 10, col = 13 }, -- inside t.Run
        expected_tests = {
          {
            name = 'TestFunctionWithEmptyTableTestCases',
            selector = '^TestFunctionWithEmptyTableTestCases$',
          },
        },
      },
      {
        name = 'test function with subtests nested inside table test - cursor inside test case',
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
        ]],                             -- go
        cursor = { row = 8, col = 13 }, -- inside TestCase1
        expected_tests = {
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$',
          },
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase1',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase1$',
          },
        },
      },
      {
        name = 'test function with subtests nested inside table test - cursor inside subtest',
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
        ]],                              -- go
        cursor = { row = 22, col = 17 }, -- inside Subtest1
        expected_tests = {
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$',
          },
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase1',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase1$',
          },
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase1/Subtest1',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase1$/^Subtest1$',
          },
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase2',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase2$',
          },
          {
            name = 'TestFunctionWithSubtestsNestedInsideTableTest/TestCase2/Subtest1',
            selector = '^TestFunctionWithSubtestsNestedInsideTableTest$/^TestCase2$/^Subtest1$',
          },
        },
      },
      {
        name = 'test function with table tests nested inside subtest - cursor inside test case',
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
        ]],                             -- go
        cursor = { row = 9, col = 17 }, -- inside TestCase1
        expected_tests = {
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$',
          },
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$',
          },
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1/TestCase1',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$/^TestCase1$',
          },
        },
      },
      {
        name = 'test function with table tests nested inside subtest - cursor inside t.Run',
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
        ]],                              -- go
        cursor = { row = 22, col = 17 }, -- inside t.Run
        expected_tests = {
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$',
          },
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$',
          },
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1/TestCase1',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$/^TestCase1$',
          },
          {
            name = 'TestFunctionWithTableTestsNestedInsideSubtest/Subtest1/TestCase2',
            selector = '^TestFunctionWithTableTestsNestedInsideSubtest$/^Subtest1$/^TestCase2$',
          },
        },
      },
    }

    for _, tc in ipairs(test_cases) do
      it(tc.name, function()
        local root, teardown_tree = temptree.create({
          ['foo_test.go'] = tc.file,
        })

        vim.cmd('edit ' .. root .. '/foo_test.go')
        cursor.set(tc.cursor)

        local tests, err = parsingv2.list_tests_at_cursor()

        assert.is_nil(err, 'expected no error to be returned')
        assert.are.same(tc.expected_tests, tests, 'incorrect tests returned')

        teardown_tree()
      end)
    end
  end)

  it('returns error if language of file is not supported', function()
    local root, teardown_tree = temptree.create({
      ['hello.rb'] = 'puts "Hello, World!"', -- ruby
    })

    vim.cmd('edit ' .. root .. '/hello.rb')

    local tests, err = parsingv2.list_tests_at_cursor()

    assert.are.equal(err, 'finding tests is not supported for ruby files')
    assert.is_nil(tests, 'expected no tests to be returned')

    teardown_tree()
  end)

  it('returns error if cursor is not in a test', function()
    local root, teardown_tree = temptree.create({
      ['foo_test.go'] = [[
        func Func() {
            fmt.Println("foo")
        }
      ]], -- go
    })

    vim.cmd('edit ' .. root .. '/' .. 'foo_test.go')
    cursor.set({ row = 2, col = 5 })

    local tests, err = parsingv2.list_tests_at_cursor()

    assert.are.equal(err, 'cursor is not in a test')
    assert.is_nil(tests, 'expected no tests to be returned')

    teardown_tree()
  end)
end)
