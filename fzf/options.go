package fzf

import (
	"fmt"
	"github.com/junegunn/fzf/src/iosbridge"
)

// ValidateEmbedded rejects OS process ownership before any goroutine starts.
func ValidateEmbedded(opts *Options) error {
	if opts.ListenAddr != nil || opts.useTmux() || opts.useZellij() || opts.Preview.command != "" || opts.InfoCommand != "" {
		return fmt.Errorf("embedded fzf does not support preview processes, listeners or external multiplexers")
	}
	if iosbridge.Getenv("FZF_DEFAULT_COMMAND") != "" {
		return fmt.Errorf("embedded fzf requires piped input instead of FZF_DEFAULT_COMMAND")
	}
	for _, actions := range opts.Keymap {
		for _, action := range actions {
			if processExecution(action.t) || action.t == actSigStop || action.t == actBecome || action.t == actChangePreview {
				return fmt.Errorf("embedded fzf does not support action %s", action.t.Name())
			}
		}
	}
	return nil
}
