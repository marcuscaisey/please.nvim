package main

import (
	"bufio"
	"encoding/xml"
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
)

type TestSuite struct {
	XMLName   xml.Name    `xml:"testsuite"`
	Name      string      `xml:"name,attr"`
	Tests     int         `xml:"tests,attr"`
	Skipped   int         `xml:"skipped,attr"`
	Failures  int         `xml:"failures,attr"`
	TestCases []*TestCase `xml:"testcase,omitempty"`
}

type TestCase struct {
	Name    string   `xml:"name,attr"`
	Failure *Failure `xml:"failure,omitempty"`
	Skipped *Skipped `xml:"skipped,omitempty"`
}

type Failure struct {
	Message string `xml:"message,attr"`
	Value   string `xml:",cdata"`
}

type Skipped struct{}

var testFilePattern = regexp.MustCompile(`^Testing: \t(.+)$`)
var outcomePattern = regexp.MustCompile(`^\x1B\[.+m(\w+)\x1B\[0m\t\|\|\t(.+)$`)
var resultsPattern = regexp.MustCompile(`^\x1B\[32mSuccess: `)

func main() {
	testSuite := &TestSuite{}

	scanner := bufio.NewScanner(os.Stdin)

	// Skip header
	scanner.Scan()
	scanner.Scan()

	outputLinesByFailure := map[*Failure][]string{}
	for scanner.Scan() {
		line := scanner.Text()

		if matches := testFilePattern.FindStringSubmatch(line); len(matches) > 0 {
			testSuite.Name = strings.TrimSpace(matches[1])

		} else if matches := outcomePattern.FindStringSubmatch(line); len(matches) > 0 {
			testSuite.Tests++
			testCase := &TestCase{
				Name: strings.TrimSpace(matches[2]),
			}
			testSuite.TestCases = append(testSuite.TestCases, testCase)

			switch matches[1] {
			case "Success":
			case "Fail":
				testSuite.Failures++
				testCase.Failure = &Failure{}
			case "Pending":
				testSuite.Skipped++
				testCase.Skipped = &Skipped{}
			}

		} else if resultsPattern.MatchString(line) {
			break

		} else if currentFailure := testSuite.TestCases[len(testSuite.TestCases)-1].Failure; currentFailure != nil {
			if currentFailure.Message == "" {
				currentFailure.Message = strings.TrimSpace(line)
			} else {
				outputLinesByFailure[currentFailure] = append(outputLinesByFailure[currentFailure], strings.TrimPrefix(line, strings.Repeat(" ", 12)))
			}
		}
	}

	for failure, outputLines := range outputLinesByFailure {
		failure.Value = strings.TrimSpace(strings.Join(outputLines, "\n"))
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	xmlBytes, err := xml.MarshalIndent(testSuite, "", "  ")
	if err != nil {
		log.Fatalf("marshalling test suite to XML: %s", err)
	}
	fmt.Println(string(xmlBytes))
}
