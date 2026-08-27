;;; user-install.el --- install user packages from batch -*- lexical-binding: t; -*-

;; Entry point for `ee --user-install'. Runs with -Q as a separate process so
;; that installing and natively compiling does not block the running daemon.
;;
;; package.el warns that -Q keeps it from recording installs in custom-file.
;; That is fine here: packages.el is the source of truth for what should be
;; installed, and writing custom-file from a second process would race with the
;; daemon that owns it.

;;; Code:

(let ((config-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path (expand-file-name "user-lisp" config-dir))

  (require 'package)
  (setq package-archives
        '(("gnu"    . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
          ("melpa"  . "https://melpa.org/packages/"))
        native-comp-async-report-warnings-errors nil
        byte-compile-warnings nil)
  (package-initialize)

  (require 'devmacs-user)
  (devmacs-user-install))

;;; user-install.el ends here
