package gopkg_test

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

type testSuiteInAnotherFile struct {
	suite.Suite
}

func TestSuiteInAnotherFile(t *testing.T) {
	suite.Run(t, &testSuiteInAnotherFile{})
}
