#!/bin/sh
# Checks that need no container, so they can run on every platform. This is the
# only place the Windows launchers can be exercised at all, since neither the
# Windows nor the macOS hosted runners can run Linux containers.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

EE="${REPO_DIR}/ee"

# --help has to work before any runtime is looked for: it is the first thing
# someone runs on a machine where nothing is set up yet.
out="$("$EE" --help 2>&1)" || bad "--help exited non-zero"
contains "usage states the action form" "$out" "Usage: ee [action]"

for action in --shell --exec --user-install --pull --restart --stop --status; do
    contains "usage lists $action" "$out" "$action"
done

# The README points at --help for these instead of repeating them, so they have
# to actually be there.
for var in DEVMACS_IMAGE DEVMACS_NAME DEVMACS_WORKSPACE DEVMACS_USER_CONFIG \
           DEVMACS_STATE_DIR DEVMACS_RUNTIME; do
    contains "usage lists $var" "$out" "$var"
done

# An unknown action must not be taken for a file name and passed to Emacs.
if "$EE" --nonsense >/dev/null 2>&1; then
    bad "an unknown action exited zero"
else
    ok "an unknown action is rejected"
fi

# Pinning a runtime that is not installed has to fail loudly rather than
# quietly falling back to another one.
if err="$(DEVMACS_RUNTIME=definitely-not-installed "$EE" --status 2>&1)"; then
    bad "a missing pinned runtime exited zero"
else
    ok "a missing pinned runtime fails"
    contains "and names it" "$err" "definitely-not-installed"
fi

finish
