#!/bin/sh
#
# Runs as root first so that uid/gid can be lined up with the host, then drops
# to dev. Without that, anything written into a bind-mounted source tree comes
# out root-owned on the host. Docker Desktop on macOS papers over this with
# VirtioFS, but Apple container, plain Linux and WSL do not.
#
set -eu

DEV_USER=dev
DEV_HOME=/home/dev
SEED_DIR=/opt/devmacs/seed

emacs_d="${DEV_HOME}/.emacs.d"
mise_dir="${MISE_DATA_DIR:-${DEV_HOME}/.local/share/mise}"

# Packages were installed and natively compiled at build time, but they cannot
# be shipped in $HOME/.emacs.d: the state volume mounted there would hide them.
# They arrive as a seed and get unpacked once instead.
seed_state() {
    if [ ! -e "${emacs_d}/.devmacs-seeded" ]; then
        if [ -d "$SEED_DIR" ]; then
            cp -a "${SEED_DIR}/." "${emacs_d}/"
        fi
        : > "${emacs_d}/.devmacs-seeded"
    fi
}

if [ "$(id -u)" = "0" ]; then
    want_uid="${DEVMACS_UID:-1000}"
    want_gid="${DEVMACS_GID:-1000}"
    have_uid="$(id -u "$DEV_USER")"
    have_gid="$(id -g "$DEV_USER")"

    if [ "$want_gid" != "$have_gid" ]; then
        groupmod -o -g "$want_gid" "$DEV_USER"
    fi
    if [ "$want_uid" != "$have_uid" ]; then
        usermod -o -u "$want_uid" "$DEV_USER"
    fi

    # Seeding while still root keeps ownership correct in one pass.
    mkdir -p "$emacs_d" "$mise_dir"
    seed_state

    chown "$want_uid:$want_gid" "$DEV_HOME" 2>/dev/null || true
    chown "$want_uid:$want_gid" \
        "${DEV_HOME}/.local" "${DEV_HOME}/.local/share" 2>/dev/null || true

    # Volumes turn up owned by root, so they need fixing, but elpa and
    # eln-cache hold thousands of files - only walk them when ownership is
    # actually wrong.
    for dir in "$emacs_d" "$mise_dir"; do
        if [ "$(stat -c %u "$dir")" != "$want_uid" ] \
           || [ "$(stat -c %g "$dir")" != "$want_gid" ]; then
            chown -R "$want_uid:$want_gid" "$dir"
        fi
    done

    # /workspace is deliberately left alone. It is a bind mount, so chown would
    # rewrite ownership of the host's own files on Linux. Matching the uid is
    # this script's job; taking over the user's files is not.

    exec gosu "$DEV_USER" "$0" "$@"
fi

# Reached directly when the container is started with --user.
mkdir -p "$emacs_d" "$mise_dir"
seed_state

# Mounted repositories rarely match the container user, and this is a
# development container, so the dubious-ownership check only gets in the way.
if [ ! -e "${DEV_HOME}/.gitconfig" ]; then
    git config --global --add safe.directory '*'
fi

exec "$@"
