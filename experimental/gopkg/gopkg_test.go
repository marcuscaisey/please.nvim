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
	t.Run("TestNameInCamelCase", func(t *testing.T) {
		t.Fatal("oh no")
	})

	t.Run("test name in snake case", func(t *testing.T) {
		t.Fatal("oh no")
	})
}

func TestFunctionWithTableTests(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			t.Fatal("oh no")
		})
	}
}

func TestFunctionWithVarTableTests(t *testing.T) {
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

func TestFunctionWithSubtestsNestedInsideTableTests(t *testing.T) {
	testCases := []struct {
		name  string
		input int
		want  int
	}{
		{
			name:  "TestName",
			input: 1,
			want:  2,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Run("SubtestName", func(t *testing.T) {
				t.Run("another one", func(t *testing.T) {
					t.Fatal("oh no")
				})
			})
		})
	}
}

func TestFunctionWithTableTestNestedInsideSubtest(t *testing.T) {
	t.Run("SubtestName", func(t *testing.T) {
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
			t.Run(tc.name, func(t *testing.T) {
				t.Fatal("oh no")
			})
		}
	})
}

type testSuite struct {
	suite.Suite
}

func TestSuite(t *testing.T) {
	suite.Run(t, &testSuite{})
}

func (s *testSuite) TestSuiteMethod1() {
	s.FailNow("oh no")
}

func (s *testSuite) TestSuiteMethod2() {
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
