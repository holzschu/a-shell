// Package iosbridge holds one invocation's owned streams, never process fd 0/1/2.
package iosbridge

/*
int fzf_terminal_input(void);
int fzf_terminal_raw(int);
int fzf_terminal_size(int *, int *);
*/
import "C"
import (
	"os"
	"sync"
	"syscall"
)

var Stdin, Stdout, Stderr *os.File
var Environment map[string]string
var InputTTY bool

func Getenv(name string) string            { return Environment[name] }
func LookupEnv(name string) (string, bool) { v, ok := Environment[name]; return v, ok }
func Environ() []string {
	result := make([]string, 0, len(Environment))
	for k, v := range Environment {
		result = append(result, k+"="+v)
	}
	return result
}
func Input() (*os.File, error) {
	fd := int(C.fzf_terminal_input())
	if fd < 0 {
		return nil, syscall.ENOTTY
	}
	return os.NewFile(uintptr(fd), "a-Shell keyboard"), nil
}
func Raw(enabled bool) error {
	value := 0
	if enabled {
		value = 1
	}
	if e := C.fzf_terminal_raw(C.int(value)); e != 0 {
		return syscall.Errno(e)
	}
	return nil
}
func Size() (int, int, error) {
	var columns, rows C.int
	if e := C.fzf_terminal_size(&columns, &rows); e != 0 {
		return 0, 0, syscall.Errno(e)
	}
	return int(columns), int(rows), nil
}

// Join workers before a later invocation may replace the stream snapshot.
var workers sync.WaitGroup

func Add()  { workers.Add(1) }
func Done() { workers.Done() }
func Wait() { workers.Wait() }
