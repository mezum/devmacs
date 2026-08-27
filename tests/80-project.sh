#!/bin/sh
# A container is scoped to one project, so that mounting does not hand it every
# file the user owns. Needs no running container: --status only reports.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
make_fixture

# No DEVMACS_WORKSPACE here - the point is what ee picks on its own.
status_at() { (cd "$1" && "${REPO_DIR}/ee" --status 2>&1); }
field() { status_at "$1" | grep "^$2" | sed 's/^[a-z ]*: //'; }

check "a repository root becomes the workspace" \
      "$(field "${FIXTURE_DIR}/projects/one" workspace)" \
      "${FIXTURE_DIR}/projects/one -> /workspace"

check "so does it from a subdirectory" \
      "$(field "${FIXTURE_DIR}/projects/one/src" workspace)" \
      "${FIXTURE_DIR}/projects/one -> /workspace"

# Same project, same daemon, wherever inside it ee was run.
check "a subdirectory reaches the same container" \
      "$(field "${FIXTURE_DIR}/projects/one/src" container)" \
      "$(field "${FIXTURE_DIR}/projects/one" container)"

# Different projects must not share one, or the mount would have to cover both.
one="$(field "${FIXTURE_DIR}/projects/one" container)"
two="$(field "${FIXTURE_DIR}/projects/two" container)"
if [ "$one" = "$two" ]; then
    bad "separate projects share a container ($one)"
else
    ok "separate projects get separate containers"
fi

# Outside a repository there is nothing to walk up to, so the directory itself
# is the most that should be exposed. Made under a temporary directory rather
# than in the fixture, since the fixture sits inside this repository and its
# .git would be found first - correctly, but not what is being checked here.
loose="$(mktemp -d)"
check "a directory outside any repository stands alone" \
      "$(field "$loose" workspace)" \
      "$(cd "$loose" && pwd -P) -> /workspace"
rm -rf "$loose"

# $HOME is still reachable for anyone who wants the old behaviour.
check "an explicit workspace still wins" \
      "$(cd "${FIXTURE_DIR}/projects/one/src" \
         && DEVMACS_WORKSPACE="${FIXTURE_DIR}/projects" "${REPO_DIR}/ee" --status 2>&1 \
         | grep '^workspace' | sed 's/^[a-z ]*: //')" \
      "${FIXTURE_DIR}/projects -> /workspace"

finish
