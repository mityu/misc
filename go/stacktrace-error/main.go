package main

import (
	"fmt"
	"runtime"
	"strings"
)

type StacktracedError struct {
	s []runtime.Frame
	e error
}

func (e StacktracedError) Unwrap() error {
	return e.e
}

func (e StacktracedError) Error() string {
	m := make([]string, 1, len(e.s)*2+1)
	m[0] = e.e.Error()
	for _, f := range e.s {
		m = append(m, fmt.Sprintf("%s()", f.Function), fmt.Sprintf("    %s:%d", f.File, f.Line))
	}
	return strings.Join(m, "\n")
}

func Wrap(e error) error {
	if _, ok := e.(StacktracedError); ok {
		return e
	}

	skip := 1
	chunkSize := 10
	buf := make([]uintptr, chunkSize)
	w := StacktracedError{s: make([]runtime.Frame, 0, chunkSize), e: e}

	for {
		l := runtime.Callers(skip, buf)
		if l == 0 {
			break
		}
		frames := runtime.CallersFrames(buf[:l])
		for {
			f, more := frames.Next()
			w.s = append(w.s, f)
			if !more {
				break
			}
		}
		if l < chunkSize {
			break
		}
		skip += l
	}

	return w
}

func main() {
	err := fmt.Errorf("test error")
	fmt.Println(err)
	fmt.Println("------------------------------")

	err = Wrap(err)
	fmt.Println(err)
	fmt.Println("------------------------------")

	err = Wrap(err)
	fmt.Println(err)
	fmt.Println("------------------------------")
}
