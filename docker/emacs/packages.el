;;; packages.el --- package list -*- lexical-binding: t; -*-

;; Read by both the build-time bake (bootstrap.el) and the runtime load
;; (init.el), so packages are declared in exactly one place.

;;; Code:

(defconst devmacs-packages
  '(vertico
    orderless
    marginalia
    consult
    corfu
    ;; Emacs 31 runs child frames on a TTY, so corfu itself works in the
    ;; terminal. This stays as a fallback for terminals where it does not.
    corfu-terminal
    cape
    buffer-env
    magit
    treesit-auto
    markdown-mode
    yaml-mode
    dockerfile-mode
    ;; eat rather than vterm, because it needs no dynamic module built.
    eat)
  "Packages installed from ELPA.")

(defconst devmacs-vc-packages
  '((eglot-booster . "https://github.com/jdtsmith/eglot-booster"))
  "Packages not published to ELPA, installed from their repository.")

(provide 'devmacs-packages)
;;; packages.el ends here
