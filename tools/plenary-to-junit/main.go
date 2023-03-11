package main

import (
	"bufio"
	"encoding/xml"
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
)

type TestSuite struct {
	XMLName   xml.Name    `xml:"testsuite"`
	Name      string      `xml:"name,attr"`
	Tests     int         `xml:"tests,attr"`
	Failures  int         `xml:"failures,attr"`
	Skipped   int         `xml:"skipped,attr"`
	Errors    int         `xml:"errors,attr"`
	TestCases []*TestCase `xml:"testcase,omitempty"`
}

type TestCase struct {
	Name    string   `xml:"name,attr"`
	Pass    bool     `xml:"-"`
	Failure *Failure `xml:"failure,omitempty"`
	Skipped *Skipped `xml:"skipped,omitempty"`
	Error   *Error   `xml:"error,omitempty"`
}

type Failure struct {
	Message string `xml:"message,attr"`
	Value   string `xml:",cdata"`
}

type Skipped struct{}

type Error struct {
	Message string `xml:"message,attr,omitempty"`
	Value   string `xml:",cdata"`
}

var (
	suiteNamePattern     = regexp.MustCompile(`^Testing:\s+(.+)$`)
	outcomePattern       = regexp.MustCompile(`^\x1B\[\d+m(\w+)\x1B\[0m\s+\|\|\s+(.+)$`)
	successCountPattern  = regexp.MustCompile(`^\x1B\[32mSuccess:`)
	failedCountPattern   = regexp.MustCompile(`^\x1B\[31mFailed :`)
	errorsCountPattern   = regexp.MustCompile(`^\x1B\[31mErrors :`)
	escapeSeqPattern     = regexp.MustCompile(`\x1B\[\d+m`)
	unexpectedErrPattern = regexp.MustCompile(`^We had an unexpected error:\s+`)
	separator            = strings.Repeat("=", 40)

	logger = log.New(os.Stderr, "Converting plenary test output to JUnit XML report: ", 0)
)

func assertLineIs(lines []string, i int, expected string, suiteName string) {
	if len(lines) <= i {
		printErrorSuiteAndExit(lines, suiteName, "expected line %d to be %q, only %d lines in input", i+1, expected, len(lines))
	}
	line := strings.TrimSpace(lines[i])
	if line != expected {
		printErrorSuiteAndExit(lines, suiteName, "expected line %d to be %q, got %q", i+1, expected, line)
	}
}

func assertLineMatches(lines []string, i int, expected *regexp.Regexp, suiteName string) []string {
	if len(lines) <= i {
		printErrorSuiteAndExit(lines, suiteName, "expected line %d to match regex %q, only %d lines in input", i+1, expected, len(lines))
	}
	line := strings.TrimSpace(lines[i])
	matches := expected.FindStringSubmatch(line)
	if len(matches) == 0 {
		printErrorSuiteAndExit(lines, suiteName, "expected line %d to match regex %q, got %q", i+1, expected, line)
	}
	return matches
}

func printErrorSuiteAndExit(lines []string, testName string, msg string, args ...interface{}) {
	maxPad := len(strconv.Itoa(len(lines)))
	numberedLines := make([]string, len(lines))
	for i, line := range lines {
		numberedLines[i] = escapeSeqPattern.ReplaceAllLiteralString(fmt.Sprintf("%*d| %s", maxPad, i+1, line), "")
	}
	testSuite := &TestSuite{
		Tests:  1,
		Errors: 1,
		TestCases: []*TestCase{
			{
				Name: testName,
				Error: &Error{
					Message: fmt.Sprintf("Converting plenary test output to JUnit XML report: %s", fmt.Sprintf(msg, args...)),
					Value:   strings.Join(numberedLines, "\n"),
				},
			},
		},
	}
	xmlBytes, err := xml.MarshalIndent(testSuite, "", "  ")
	if err != nil {
		logger.Fatalf("marshalling TestSuite to XML: %s", err)
	}
	fmt.Println(string(xmlBytes))
	// Please spits out a "Test returned nonzero but reported no errors" if a nonzero code is returned but there are no
	// failures in the XML report. It doesn't check whether there are any errors. We return a 0 to get around this.
	os.Exit(0)
}

func lastDottedPart(s string) string {
	parts := strings.Split(s, ".")
	return parts[len(parts)-1]
}

func main() {
	var lines []string
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if scanner.Err() != nil {
		logger.Fatalf("reading input from stdin: %s\n", scanner.Err())
	}

	assertLineIs(lines, 0, "", "")
	assertLineIs(lines, 1, separator, "")

	suiteNameMatches := assertLineMatches(lines, 2, suiteNamePattern, "")
	suite := &TestSuite{
		Name: strings.ReplaceAll(strings.TrimSuffix(suiteNameMatches[1], ".lua"), "/", "."),
	}

	outputLinesByFailure := map[*Failure][]string{}

	for i := 2; i < len(lines); i++ {
		trimmedLine := strings.TrimSpace(lines[i])

		if matches := outcomePattern.FindStringSubmatch(trimmedLine); len(matches) > 0 {
			suite.Tests++
			testCase := &TestCase{
				Name: matches[2],
			}
			switch matches[1] {
			case "Success":
				testCase.Pass = true
			case "Fail":
				suite.Failures++
				testCase.Failure = &Failure{}
			case "Pending":
				suite.Skipped++
				testCase.Skipped = &Skipped{}
			}
			suite.TestCases = append(suite.TestCases, testCase)

		} else if successCountPattern.MatchString(trimmedLine) {
			assertLineMatches(lines, i+1, failedCountPattern, lastDottedPart(suite.Name))
			assertLineMatches(lines, i+2, errorsCountPattern, lastDottedPart(suite.Name))
			assertLineIs(lines, i+3, separator, lastDottedPart(suite.Name))

			if i+4 < len(lines) && unexpectedErrPattern.MatchString(lines[i+4]) {
				suite.Tests++
				suite.Errors++
				errorLines := make([]string, len(lines)-(i+4))
				errorLines[0] = unexpectedErrPattern.ReplaceAllLiteralString(lines[i+4], "")
				copy(errorLines[1:], lines[i+5:])
				suite.TestCases = append(suite.TestCases, &TestCase{
					Name: lastDottedPart(suite.Name),
					Error: &Error{
						Message: `Unexpected error reported. This usually occurs when an error is raised outside of an "it" block.`,
						Value:   strings.Join(errorLines, "\n"),
					},
				})
				break

			} else if suite.Failures > 0 {
				assertLineIs(lines, i+4, "Tests Failed. Exit: 1", lastDottedPart(suite.Name))
				i = i + 4

			} else {
				i = i + 3
			}

		} else if len(suite.TestCases) > 0 && suite.TestCases[len(suite.TestCases)-1].Failure != nil {
			currentFailure := suite.TestCases[len(suite.TestCases)-1].Failure
			if currentFailure.Message == "" {
				currentFailure.Message = trimmedLine
			} else {
				outputLinesByFailure[currentFailure] = append(outputLinesByFailure[currentFailure], strings.TrimPrefix(lines[i], strings.Repeat(" ", 12)))
			}

		} else if trimmedLine == separator {
			assertLineIs(lines, i+1, "FAILED TO LOAD FILE", lastDottedPart(suite.Name))
			if len(lines) <= i+2 {
				printErrorSuiteAndExit(lines, lastDottedPart(suite.Name), "expected line %d after %q, only %d lines in input", i+1, "FAILED TO LOAD FILE", len(lines))
			}
			suite.Tests++
			suite.Errors++
			suite.TestCases = append(suite.TestCases, &TestCase{
				Name: lastDottedPart(suite.Name),
				Error: &Error{
					Value: strings.TrimSpace(escapeSeqPattern.ReplaceAllLiteralString(lines[i+2], "")),
				},
			})
			assertLineIs(lines, i+3, separator, suite.Name)
			i = i + 3

		} else if len(suite.TestCases) == 0 || (trimmedLine == "" && suite.TestCases[len(suite.TestCases)-1].Pass) {

		} else {
			printErrorSuiteAndExit(lines, suite.Name, "unexpected line %d: %q", i+1, trimmedLine)
		}
	}

	for failure, outputLines := range outputLinesByFailure {
		failure.Value = strings.TrimSpace(strings.Join(outputLines, "\n"))
	}

	xmlBytes, err := xml.MarshalIndent(suite, "", "  ")
	if err != nil {
		logger.Fatalf("marshalling TestSuite to XML: %s", err)
	}
	fmt.Println(string(xmlBytes))
	if suite.Failures > 0 {
		// Please spits out a "Test returned 0 but still reported failures" if a 0 is returned but there are failures in
		// the XML report. We return a 1 to get around this.
		os.Exit(1)
	}
}