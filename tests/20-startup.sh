#!/bin/sh
# The daemon comes up and the container runs as the host user.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

check "emacsclient reaches the daemon" "$(emacs_eval '(+ 1 1)')" "2"
contains "the daemon is Emacs 31" "$(emacs_eval 'emacs-version')" "31."
check "the daemon runs as a daemon" "$(emacs_eval '(daemonp)')" "t"

# Anything written into a bind mount would come out root-owned on the host
# otherwise.
check "uid matches the host" "$(in_container id -u)" "$(id -u)"
check "gid matches the host" "$(in_container id -g)" "$(id -g)"
check "the process is not root" "$(in_container sh -c 'id -un')" "dev"

check "the workspace is mounted" \
      "$(in_container sh -c 'test -f /workspace/demo/mise.toml && echo yes || echo no')" \
      "yes"
check "workspace files belong to the host user" \
      "$(in_container stat -c %u /workspace/demo/mise.toml)" \
      "$(id -u)"

# The state volume arrives owned by root and has to be fixed up before Emacs
# can write to it.
check "the state directory is writable" \
      "$(in_container sh -c 'touch /home/dev/.emacs.d/.probe && echo yes || echo no')" \
      "yes"
check "the mise directory is writable" \
      "$(in_container sh -c 'touch /home/dev/.local/share/mise/.probe && echo yes || echo no')" \
      "yes"

finish
