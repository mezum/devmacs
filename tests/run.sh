#!/bin/sh
#
# Runs every check against an image. CI runs this same script, so that what is
# verified locally and what gates a release cannot drift apart. See the README
# for how to invoke it.
#
set -eu

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${TESTS_DIR}/lib.sh"

printf 'image   : %s\n' "$DEVMACS_TEST_IMAGE"
printf 'variant : %s\n' "$DEVMACS_TEST_VARIANT"
printf 'runtime : %s\n\n' "$RUNTIME"

make_fixture
start_container
trap stop_container EXIT INT TERM

if [ $# -gt 0 ]; then
    files="$*"
else
    files="$(cd "$TESTS_DIR" && ls [0-9][0-9]-*.sh)"
fi

rc=0
for file in $files; do
    printf '%s\n' "${file%.sh}"
    if sh "${TESTS_DIR}/${file}"; then :; else rc=1; fi
    printf '\n'
done

if [ "$rc" -eq 0 ]; then
    printf 'all checks passed\n'
else
    printf 'there were failures\n'
fi
exit "$rc"
