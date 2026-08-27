#!/bin/sh
#
# Shared helpers. Every test file sources this and can also be run on its own,
# so that a single failing area can be re-checked without the whole suite.
#
# shellcheck shell=sh

: "${DEVMACS_TEST_IMAGE:=devmacs:test}"
: "${DEVMACS_TEST_NAME:=devmacs-test}"
: "${DEVMACS_TEST_VARIANT:=base}"
: "${RUNTIME:=docker}"

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
# Under $REPO_DIR because Docker Desktop on macOS only shares certain paths,
# and a bind mount outside them silently resolves to an empty directory.
FIXTURE_DIR="${REPO_DIR}/.test-fixture"

failures=0

# Mirrored into the job summary when running in CI, so that a pull request
# shows what was checked without anyone opening the log.
summary() {
    [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
}

ok()  { printf '  ok    %s\n' "$*"; summary "| ✅ | $* |"; }
bad() { printf '  FAIL  %s\n' "$*"; failures=$((failures + 1)); summary "| ❌ | **$*** |"; }

check() {  # check DESCRIPTION ACTUAL EXPECTED
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 -- got [$2], want [$3]"; fi
}

contains() {  # contains DESCRIPTION HAYSTACK NEEDLE
    case "$2" in
        *"$3"*) ok "$1" ;;
        *)      bad "$1 -- got [$2], want substring [$3]" ;;
    esac
}

absent() {  # absent DESCRIPTION HAYSTACK NEEDLE
    case "$2" in
        *"$3"*) bad "$1 -- [$3] should not appear in [$2]" ;;
        *)      ok "$1" ;;
    esac
}

finish() {
    if [ "$failures" -gt 0 ]; then
        printf '  %d failure(s)\n' "$failures"
        exit 1
    fi
    exit 0
}

# Each file opens its own table. Titles come from the file name so that adding
# a check never means editing a heading somewhere else.
summary_open() {
    [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
    summary ""
    summary "### $(basename "$0" .sh)"
    summary ""
    summary "|   | check |"
    summary "|---|---|"
}

# --- talking to the container -------------------------------------------

in_container() { "$RUNTIME" exec --user dev "$DEVMACS_TEST_NAME" "$@"; }

# Emacs prints elisp results with quotes and newlines; strip both so that
# results can be compared as plain strings.
emacs_eval() {
    in_container emacsclient --eval "$1" 2>/dev/null | tr -d '\n"'
}

# --- fixtures ------------------------------------------------------------

make_fixture() {
    rm -rf "$FIXTURE_DIR"
    mkdir -p "$FIXTURE_DIR/workspace/demo" \
             "$FIXTURE_DIR/workspace/plain" \
             "$FIXTURE_DIR/user-config/user-lisp"

    printf '[tools]\nnode = "22"\n' > "$FIXTURE_DIR/workspace/demo/mise.toml"
    printf 'console.log("hi")\n'    > "$FIXTURE_DIR/workspace/demo/index.js"

    # Deliberately away from mise.toml, and plain text. Opening a file next to
    # one makes buffer-env ask whether it may run it, and a source file can make
    # treesit-auto ask about a grammar; with no terminal to answer, either
    # prompt blocks the whole daemon.
    printf 'hello\n'                > "$FIXTURE_DIR/workspace/plain/a.txt"

    cat > "$FIXTURE_DIR/user-config/init.el" <<'ELISP'
;;; -*- lexical-binding: t; -*-
(require 'devmacs-test-probe)
(setq-default fill-column 72)
(defvar devmacs-test-user-init-loaded t)
ELISP

    cat > "$FIXTURE_DIR/user-config/user-lisp/devmacs-test-probe.el" <<'ELISP'
;;; -*- lexical-binding: t; -*-
(defvar devmacs-test-user-lisp-loaded t)
(provide 'devmacs-test-probe)
ELISP

    cat > "$FIXTURE_DIR/user-config/packages.el" <<'ELISP'
(setq devmacs-user-packages '(rainbow-delimiters))
ELISP
}

start_container() {
    "$RUNTIME" rm --force "$DEVMACS_TEST_NAME" >/dev/null 2>&1 || true
    "$RUNTIME" volume rm devmacs-test-emacs devmacs-test-mise >/dev/null 2>&1 || true

    "$RUNTIME" run --detach --name "$DEVMACS_TEST_NAME" \
        --env "DEVMACS_UID=$(id -u)" --env "DEVMACS_GID=$(id -g)" \
        --env "MISE_TRUSTED_CONFIG_PATHS=/workspace" \
        --volume "${FIXTURE_DIR}/workspace:/workspace" \
        --volume "${FIXTURE_DIR}/user-config:/opt/devmacs/user:ro" \
        --volume "devmacs-test-emacs:/home/dev/.emacs.d" \
        --volume "devmacs-test-mise:/home/dev/.local/share/mise" \
        "$DEVMACS_TEST_IMAGE" >/dev/null

    i=0
    while [ "$i" -lt 90 ]; do
        if in_container emacsclient --eval t >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done
    printf 'the daemon did not come up. Logs:\n' >&2
    "$RUNTIME" logs "$DEVMACS_TEST_NAME" >&2 2>&1 || true
    return 1
}

stop_container() {
    "$RUNTIME" rm --force "$DEVMACS_TEST_NAME" >/dev/null 2>&1 || true
    "$RUNTIME" volume rm devmacs-test-emacs devmacs-test-mise >/dev/null 2>&1 || true
    rm -rf "$FIXTURE_DIR"
}

# Running a file on its own should still work, so bring the container up if the
# runner has not already done it.
ensure_container() {
    if in_container true >/dev/null 2>&1; then
        return 0
    fi
    make_fixture
    start_container
}

# run.sh drives the files rather than being one, so it opens no table.
case "$(basename "$0")" in
    run.sh) ;;
    *) summary_open ;;
esac
