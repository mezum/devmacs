#!/bin/sh
# Packages built into the image reach the state volume, so that no machine
# waits for native compilation on first start.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ensure_container

check "the seed was unpacked" \
      "$(in_container sh -c 'test -e /home/dev/.emacs.d/.devmacs-seeded && echo yes || echo no')" \
      "yes"
check "the stub init.el is in place" \
      "$(in_container sh -c 'test -f /home/dev/.emacs.d/init.el && echo yes || echo no')" \
      "yes"

check "elpa is populated" \
      "$(in_container sh -c '[ "$(ls /home/dev/.emacs.d/elpa | wc -l)" -gt 5 ] && echo yes || echo no')" \
      "yes"
check "eln files were shipped" \
      "$(in_container sh -c '[ "$(find /home/dev/.emacs.d/eln-cache -name "*.eln" | wc -l)" -gt 50 ] && echo yes || echo no')" \
      "yes"

check "native compilation is available" "$(emacs_eval '(native-comp-available-p)')" "t"

# The point of shipping eln at all is that the very first start does not have to
# compile. A byte-code function here means the shipped files were ignored and
# JIT is redoing the work - which is what happens if they were compiled under a
# different absolute path than the one used at runtime.
for fn in vertico-mode corfu-mode marginalia-mode cape-file buffer-env-update; do
    check "$fn came from eln" \
          "$(emacs_eval "(and (subrp (symbol-function '$fn)) t)")" "t"
done

# Most packages are deferred, so they are only proven once something pulls them
# in. magit is the heaviest of them and the most worth not compiling by hand.
check "deferred packages come from eln as well" \
      "$(emacs_eval '(progn (require (quote magit)) (and (subrp (symbol-function (quote magit-status))) t))')" \
      "t"

for pkg in vertico orderless marginalia corfu cape buffer-env; do
    check "$pkg is loaded" "$(emacs_eval "(and (featurep '$pkg) t)")" "t"
done

# The config lives in the image and only state belongs on the volume, so what
# sits in $HOME/.emacs.d must be a stub rather than the real configuration.
check "the config lives outside the state volume" \
      "$(in_container sh -c 'test -f /opt/devmacs/config/init.el && echo yes || echo no')" \
      "yes"
contains "the state init.el is only a stub" \
         "$(in_container cat /home/dev/.emacs.d/init.el)" \
         "DEVMACS_CONFIG"

finish
