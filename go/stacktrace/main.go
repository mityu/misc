package main

import (
	"fmt"
	"os"
	"runtime"
	"strings"
)

func getStackTrace() string {
	skip := 0
	chunkSize := 5
	result := []string{}
	stack := make([]uintptr, chunkSize)

	for {
		length := runtime.Callers(skip, stack)
		if length <= 0 {
			break
		}
		frames := runtime.CallersFrames(stack[:length])
		for {
			frame, more := frames.Next()
			result = append(result, frame.Function+"()", fmt.Sprintf("    %s:%d", frame.File, frame.Line))
			if !more {
				break
			}
		}
		if length < chunkSize {
			break
		}
		skip += length
	}

	return strings.Join(result, "\n")
}

func f1() {
	f2()
}

func f2() {
	// some comment
	f3()
}

func f3() {
	stack := getStackTrace()
	fmt.Println(stack)
}

func run() error {
	f1()
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
