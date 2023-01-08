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

func TestFunctionWithSubTests(t *testing.T) {
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

func TestFunctionWithVarSubTests(t *testing.T) {
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

func TestFunctionWithEmptySubTestCases(t *testing.T) {
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

func (s *testSuite) TestSuiteMethodWithSubTests() {
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

func (s *testSuite) TestSuiteMethodWithVarSubTests() {
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

func (s *testSuite) TestSuiteMethodWithEmptySubTestCases() {
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
