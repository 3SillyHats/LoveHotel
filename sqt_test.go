package main

import (
	"testing"
)

func TestNew(t *testing.T) {
	s := NewSQT()
	m := s.Matrix()
	identity := [16]float32{
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}
	if m != identity {
		t.Error("NewSQT did not return identity transformation")
	}
}
