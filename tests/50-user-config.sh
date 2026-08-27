#!/bin/sh
# A user's own configuration is layered on top of the one in the image, so that
# image updates never wipe it.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

check "the user config directory is mounted" \
      "$(emacs_eval 'devmacs-user-config-directory')" "/opt/devmacs/user"
check "the user init.el was loaded" \
      "$(emacs_eval '(and (boundp (quote devmacs-test-user-init-loaded)) devmacs-test-user-init-loaded)')" "t"
check "user-lisp reached load-path" \
      "$(emacs_eval '(and (boundp (quote devmacs-test-user-lisp-loaded)) devmacs-test-user-lisp-loaded)')" "t"

# Loading after the base config is what lets a user override it; the base sets
# fill-column to 100 and the fixture sets it to 72.
check "the user config wins over the base one" \
      "$(emacs_eval '(default-value (quote fill-column))')" "72"

# Installing from a separate -Q process keeps native compilation from blocking
# the daemon people are editing in.
in_container emacs --batch -Q --init-directory=/home/dev/.emacs.d \
    -l /opt/devmacs/config/user-install.el >/dev/null 2>&1 \
    || bad "user-install failed"

check "the declared package was installed" \
      "$(in_container sh -c 'ls -d /home/dev/.emacs.d/elpa/rainbow-delimiters* >/dev/null 2>&1 && echo yes || echo no')" \
      "yes"
check "it was natively compiled" \
      "$(in_container sh -c '[ "$(find /home/dev/.emacs.d/eln-cache -name "rainbow-delimiters*.eln" | wc -l)" -gt 0 ] && echo yes || echo no')" \
      "yes"
check "it survives on the state volume" \
      "$(emacs_eval '(progn (package-initialize) (and (require (quote rainbow-delimiters) nil t) t))')" \
      "t"

finish
