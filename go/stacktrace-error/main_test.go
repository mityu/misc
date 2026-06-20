package main

import (
	"errors"
	"os"
	"testing"
)

func TestErrorsIs(t *testing.T) {
	err := Wrap(os.ErrExist)
	if !errors.Is(err, os.ErrExist) {
		t.Error("Should be true")
	}
}

func TestAvoidDoubleWrap(t *testing.T) {
	err, ok := Wrap(Wrap(os.ErrExist)).(StacktracedError)
	if !ok {
		t.Fatal("unreachable")
	}
	if err.e != os.ErrExist {
		t.Error("double wrap")
	}
}
