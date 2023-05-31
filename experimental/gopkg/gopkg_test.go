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
	s.Run("PascalCaseName", func() {
		s.Fail("oh no")
	})

	s.Run("snake case name", func() {
		s.Fail("oh no")
	})
}

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
