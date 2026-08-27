#!/bin/sh
# A relative file argument has to resolve against the directory ee was run
# from. It used to resolve against the image's WORKDIR instead, so `ee a.txt`
# in a subdirectory wrote to the workspace root.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

# Point ee at the container the rest of the suite already started. stdin is
# closed because exec keeps it open, which leaves anything that reads it -
# emacsclient among them - waiting forever with no terminal attached.
run_ee() {
    DEVMACS_IMAGE="$DEVMACS_TEST_IMAGE" \
    DEVMACS_NAME="$DEVMACS_TEST_NAME" \
    DEVMACS_WORKSPACE="${FIXTURE_DIR}/workspace" \
    DEVMACS_USER_CONFIG="${FIXTURE_DIR}/user-config" \
        "${REPO_DIR}/ee" "$@" < /dev/null
}

check "the workspace root maps to /workspace" \
      "$(cd "${FIXTURE_DIR}/workspace" && run_ee --exec pwd)" \
      "/workspace"

check "a subdirectory is carried across" \
      "$(cd "${FIXTURE_DIR}/workspace/plain" && run_ee --exec pwd)" \
      "/workspace/plain"

check "a relative path resolves against it" \
      "$(cd "${FIXTURE_DIR}/workspace/plain" && run_ee --exec readlink -f a.txt)" \
      "/workspace/plain/a.txt"

# The reported bug in the form it was reported: emacsclient is what resolves
# the argument, so it is what has to be checked.
(cd "${FIXTURE_DIR}/workspace/plain" && run_ee --exec emacsclient -n a.txt) >/dev/null
check "emacsclient opens the file from that directory" \
      "$(emacs_eval '(and (get-file-buffer "/workspace/plain/a.txt") t)')" \
      "t"

# Outside the workspace there is nothing to map to. Falling back to the root
# would write files somewhere that was never asked for, so this has to fail
# rather than warn - a warning is easy to miss until the damage is done.
if out="$(cd "$REPO_DIR" && run_ee --exec pwd 2>&1)"; then
    bad "outside the workspace it should have failed, got [$out]"
else
    ok "outside the workspace it refuses to run"
    contains "and says why" "$out" "outside"
fi

finish
