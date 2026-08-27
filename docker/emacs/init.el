;;; init.el --- devmacs entry point -*- lexical-binding: t; -*-

;; See stub/early-init.el for why the config sits outside user-emacs-directory.

;;; Code:

(defconst devmacs-config-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Where the devmacs configuration lives; read-only inside the image.")

(defconst devmacs-user-lisp-directory
  (expand-file-name "user-lisp" devmacs-config-directory)
  "Where the configuration modules live.

The user-lisp/ auto-compilation added in Emacs 31 only covers directories
under user-emacs-directory, so bootstrap.el compiles these at build time and
`devmacs-recompile' does it at runtime.")

(add-to-list 'load-path devmacs-config-directory)
(add-to-list 'load-path devmacs-user-lisp-directory)

(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

;; Everything is installed at build time; nothing should reach for the network
;; while the editor is running.
(require 'use-package)
(setq use-package-always-ensure nil
      use-package-always-defer t)

(require 'devmacs-terminal)
(require 'devmacs-editing)
(require 'devmacs-completion)
(require 'devmacs-lsp)
(require 'devmacs-vcs)
(require 'devmacs-commands)

;; Layered last so that a user can override anything the base config decided.
(require 'devmacs-user)
(devmacs-user-load)

;; Custom has to go to the state volume; the config directory is read-only.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file :noerror :nomessage)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;;; init.el ends here
