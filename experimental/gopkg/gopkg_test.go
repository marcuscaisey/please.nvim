package gopkg_test

import (
	"testing"

	"experimental/gopkg"
)

// basic function
func TestAdd(t *testing.T) {
	testCases := []struct {
		name string
		x, y int
		want int
	}{
		{name: "equal numbers", x: 2, y: 2, want: 4},
		{name: "different numbers", x: 2, y: 3, want: 5},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			if got := gopkg.Add(tc.x, tc.y); got != tc.want {
				t.Fatalf("Add(%v, %v) = %v, want %v", tc.x, tc.y, got, tc.want)
			}
		})
	}
}

// function with third party dep
func TestContains(t *testing.T) {
	testCases := []struct {
		name string
		s    []int
		v    int
		want bool
	}{
		{name: "value at start of slice", s: []int{1, 2, 3}, v: 1, want: true},
		{name: "value in middle of slice", s: []int{1, 2, 3}, v: 2, want: true},
		{name: "value at end of slice", s: []int{1, 2, 3}, v: 3, want: true},
		{name: "value not in slice", s: []int{1, 2, 3}, v: 4, want: false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			if got := gopkg.Contains(tc.s, tc.v); got != tc.want {
				t.Fatalf("Contains(%v, %v) is %v, want %v", tc.s, tc.v, got, tc.want)
			}
		})
	}
}
