#!/bin/sh
# Languages come from mise on a shared volume, and Emacs has to see them per
# buffer for a single daemon to serve projects that mix languages.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

in_container sh -c 'cd /workspace/demo && mise install' >/dev/null 2>&1 \
    || bad "mise install failed"

contains "the runtime is installed" \
         "$(in_container sh -c 'cd /workspace/demo && eval "$(mise env -s bash)" && node --version')" \
         "v22."

# What mise installs must land on the shared volume, not inside the container.
check "the runtime is on the shared volume" \
      "$(in_container sh -c 'ls -d /home/dev/.local/share/mise/installs/node/* >/dev/null 2>&1 && echo yes || echo no')" \
      "yes"

# buffer-env is what stops the daemon's startup environment from leaking into
# every buffer. Authorization is stubbed out because it would otherwise prompt.
probe() {
    cat <<ELISP
(with-temp-buffer
  (setq-local default-directory "/workspace/demo/")
  (cl-letf (((symbol-function (quote buffer-env--authorize)) (lambda (_) t)))
    (buffer-env-update "/workspace/demo/mise.toml"))
  $1)
ELISP
}

check "buffer-env picks up the project file" \
      "$(emacs_eval "$(probe '(and buffer-env-active t)')")" "t"
# Once a runtime is installed mise points straight at it rather than at the
# shims, so only the mise directory itself is stable enough to assert on.
contains "exec-path starts inside mise" \
         "$(emacs_eval "$(probe '(car exec-path)')")" \
         "/home/dev/.local/share/mise/"
contains "Emacs resolves the runtime" \
         "$(emacs_eval "$(probe '(executable-find "node")')")" \
         "node"
contains "the runtime actually runs from Emacs" \
         "$(emacs_eval "$(probe '(string-trim (shell-command-to-string "node --version"))')")" \
         "v22."

finish
