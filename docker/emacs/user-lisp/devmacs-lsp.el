;;; devmacs-lsp.el --- language servers and project environments -*- lexical-binding: t; -*-

;; One daemon serving several projects means the environment captured at daemon
;; startup would otherwise apply to every buffer, and eglot would pick up the
;; wrong project's server. buffer-env replaces process-environment and
;; exec-path per buffer, which is what keeps that straight.

;;; Code:

(eval-when-compile (require 'rx))

(use-package buffer-env
  :demand t
  :config
  ;; direnv is not in the image, since mise covers the same ground.
  (setq buffer-env-script-name '("mise.toml" ".mise.toml" ".env"))

  ;; buffer-env runs the command in the script's directory and reads env -0
  ;; from its output; $1 is the script path.
  (add-to-list 'buffer-env-command-alist
               (cons (rx "/" (? ".") "mise.toml" eos)
                     "eval \"$(mise env -s bash)\" && env -0"))

  (add-hook 'hack-local-variables-hook #'buffer-env-update))

;; Not started automatically: plenty of projects have no server installed, and
;; a warning on every file visit is worse than typing C-c l l.
;; Projects that always want one can put eglot-ensure in .dir-locals.el.
(use-package eglot
  :ensure nil
  :bind (("C-c l l" . eglot)
         ("C-c l r" . eglot-rename)
         ("C-c l a" . eglot-code-actions)
         ("C-c l f" . eglot-format-buffer)
         ("C-c l d" . eldoc-doc-buffer))
  :config
  (setq eglot-autoshutdown t
        eglot-sync-connect nil
        eglot-events-buffer-size 0
        eglot-extend-to-xref t))

(use-package eglot-booster
  :after eglot
  :demand t
  :config
  (if (executable-find "emacs-lsp-booster")
      (eglot-booster-mode)
    (message "devmacs: emacs-lsp-booster not found, booster disabled")))

(provide 'devmacs-lsp)
;;; devmacs-lsp.el ends here
