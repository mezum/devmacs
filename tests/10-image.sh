#!/bin/sh
# What the image is expected to contain.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

contains "emacs is 31.x" "$(in_container emacs --version | head -1)" "GNU Emacs 31"
contains "emacsclient exists" "$(in_container emacsclient --version 2>&1 | head -1)" "emacsclient"
contains "mise is installed" "$(in_container mise --version)" "linux"

# --version is not supported by the booster, so ask the shell instead.
check "emacs-lsp-booster is on PATH" \
      "$(in_container sh -c 'command -v emacs-lsp-booster')" \
      "/usr/local/bin/emacs-lsp-booster"

check "fd is aliased from fdfind" "$(in_container sh -c 'command -v fd')" "/usr/local/bin/fd"
contains "ripgrep is installed" "$(in_container rg --version | head -1)" "ripgrep"
contains "git is installed" "$(in_container git --version)" "git version"

# native-comp calls out to these at runtime for packages installed later, so
# they have to be present even though everything shipped is already AOT built.
check "libgccjit is present" \
      "$(in_container sh -c 'ls /usr/lib/*/libgccjit.so.0 >/dev/null 2>&1 && echo yes || echo no')" \
      "yes"
contains "an assembler is available" "$(in_container as --version | head -1)" "GNU assembler"

if [ "$DEVMACS_TEST_VARIANT" = "base" ]; then
    contains "base has gcc" "$(in_container gcc --version | head -1)" "gcc"
    contains "base has clang" "$(in_container clang --version | head -1)" "clang"
    contains "base has pkg-config" "$(in_container pkg-config --version)" "."
else
    check "slim has no clang" \
          "$(in_container sh -c 'command -v clang >/dev/null 2>&1 && echo yes || echo no')" \
          "no"
fi

finish
