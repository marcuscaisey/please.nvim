package gopkg_test

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

func TestFunction1(t *testing.T) {
	t.Fatal("oh no")
}

func TestFunction2(t *testing.T) {
	t.Fatal("oh no")
}

func TestFunctionWithSubtests(t *testing.T) {
	t.Run("PascalCaseName", func(t *testing.T) {
		t.Fatal("oh no")
	})

	t.Run("snake case name", func(t *testing.T) {
		t.Fatal("oh no")
	})
}

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

type testSuite struct {
	suite.Suite
}

type testSuiteWithNew struct {
	suite.Suite
}

func TestSuite(t *testing.T) {
	suite.Run(t, &testSuite{})
}

func TestSuiteWithNew(t *testing.T) {
	suite.Run(t, new(testSuiteWithNew))
}

func (s *testSuite) TestMethod1() {
	s.Fail("oh no")
}

func (s *testSuiteWithNew) TestMethod2() {
	s.Fail("oh no")
}

func (s *testSuiteInAnotherFile) TestMethod3() {
	s.Fail("oh no")
}

func (s *testSuite) TestMethodWithSubtests() {
	s.Run("TestNameInCamelCase", func() {
		s.Run("NestedSubtest", func() {
			s.Fail("oh no")
		})
	})

	s.Run("test name in snake case", func() {
		s.Fail("oh no")
	})
}

func (s *testSuite) TestMethodWithTableTests() {
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
			s.Fail("oh no")
		})
	}
}

func (s *testSuite) TestMethodWithVarTableTests() {
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
			s.Fail("oh no")
		})
	}
}

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

func (s *testSuite) TestMethodWithSubtestsNestedInsideTableTests() {
	testCases := []struct {
		name  string
		input int
		want  int
	}{
		{
			name:  "TestNameOne",
			input: 1,
			want:  2,
		},
		{
			name:  "TestNameTwo",
			input: 1,
			want:  2,
		},
	}

	for _, tc := range testCases {
		s.Run(tc.name, func() {
			s.Run("SubtestOne", func() {
			})

			s.Run("SubtestTwo", func() {
			})
		})
	}
}

func (s *testSuite) TestMethodWithTableTestNestedInsideSubtest() {
	s.Run("SubtestName", func() {
		testCases := []struct {
			name  string
			input int
			want  int
		}{
			{
				name:  "TableTestName",
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
}
