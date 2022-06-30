package gopkg

import (
	"golang.org/x/exp/slices"
)

func Add(x, y int) int {
	return x + x
}

func Contains[E comparable](s []E, v E) bool {
	return slices.Index(s, v) > 0
}
