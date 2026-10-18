package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"fmt"
	fzf "github.com/junegunn/fzf/src"
	bridge "github.com/junegunn/fzf/src/iosbridge"
	"os"
	"strings"
	"syscall"
	"unsafe"
)

func own(fd C.int, name string) (*os.File, error) {
	copy, err := syscall.Dup(int(fd))
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(copy), name), nil
}

//export fzf_embedded_run
func fzf_embedded_run(argc C.int, argv **C.char, input, output, errors, inputTTY C.int, env **C.char) C.int {
	args := unsafe.Slice(argv, int(argc))
	words := make([]string, 0, len(args))
	for _, arg := range args[1:] {
		words = append(words, C.GoString(arg))
	}
	bridge.Environment = map[string]string{}
	for p := uintptr(unsafe.Pointer(env)); p != 0; p += unsafe.Sizeof(env) {
		value := *(**C.char)(unsafe.Pointer(p))
		if value == nil {
			break
		}
		key, val, ok := strings.Cut(C.GoString(value), "=")
		if ok {
			bridge.Environment[key] = val
		}
	}
	var err error
	bridge.Stdin, err = own(input, "a-Shell stdin")
	if err != nil {
		return 2
	}
	defer bridge.Stdin.Close()
	bridge.Stdout, err = own(output, "a-Shell stdout")
	if err != nil {
		return 2
	}
	defer bridge.Stdout.Close()
	bridge.Stderr, err = own(errors, "a-Shell stderr")
	if err != nil {
		return 2
	}
	defer bridge.Stderr.Close()
	bridge.InputTTY = inputTTY != 0
	opts, err := fzf.ParseOptions(true, words)
	if err != nil {
		fmt.Fprintln(bridge.Stderr, err)
		return 2
	}
	if opts.Version {
		fmt.Fprintln(bridge.Stdout, "0.74.5 (embedded iOS)")
		return 0
	}
	if opts.Help {
		fmt.Fprint(bridge.Stdout, fzf.Usage)
		return 0
	}
	if opts.Bash || opts.Zsh || opts.Fish || opts.Nushell || opts.Man {
		fmt.Fprintln(bridge.Stderr, "Shell integration and man generation are unavailable in embedded fzf")
		return 2
	}
	if err = fzf.ValidateEmbedded(opts); err != nil {
		fmt.Fprintln(bridge.Stderr, err)
		return 2
	}
	code, err := fzf.Run(opts)
	bridge.Wait()
	if err != nil {
		fmt.Fprintln(bridge.Stderr, err)
	}
	return C.int(code)
}
func main() {}
