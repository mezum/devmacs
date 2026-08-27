#!/bin/sh
# Editor behaviour that the container makes harder than it would be natively.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

# The host clipboard is invisible from inside a container, so copying has to
# go out over OSC 52.
check "copying goes through OSC 52" \
      "$(emacs_eval 'interprogram-cut-function')" "devmacs-osc52-copy"
check "the escape sequence is well formed" \
      "$(emacs_eval '(let (sent)
                       (cl-letf (((symbol-function (quote send-string-to-terminal))
                                  ;; The real one takes an optional terminal,
                                  ;; and the trampoline passes it through.
                                  (lambda (s &optional _) (setq sent s))))
                         (devmacs-osc52-copy "hi"))
                       (and (string-prefix-p "\033]52;c;" sent) t))')" \
      "t"
# Reading it back is refused by most terminals, so pasting is left to them.
check "pasting is left to the terminal" \
      "$(emacs_eval '(or interprogram-paste-function :none)')" ":none"

# eglot-booster only helps if the wrapper is actually found.
check "eglot-booster turns on with eglot" \
      "$(emacs_eval '(progn (require (quote eglot)) (and (boundp (quote eglot-booster-mode)) eglot-booster-mode))')" \
      "t"

check "mouse support is on" "$(emacs_eval 'xterm-mouse-mode')" "t"
check "tree-sitter is compiled in" "$(emacs_eval '(and (treesit-available-p) t)')" "t"
check "modules are enabled" "$(emacs_eval '(and module-file-suffix t)')" "t"

# State has to stay on the volume rather than in the read-only config.
contains "history is kept on the state volume" \
         "$(emacs_eval 'savehist-file')" "/home/dev/.emacs.d"
contains "custom.el is kept on the state volume" \
         "$(emacs_eval 'custom-file')" "/home/dev/.emacs.d"

finish
