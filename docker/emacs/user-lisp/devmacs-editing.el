;;; devmacs-editing.el --- editing basics -*- lexical-binding: t; -*-

;; Every state file goes under user-emacs-directory, which is the state volume.
;; The config directory is read-only, so nothing can be written there anyway.

;;; Code:

(defun devmacs-state (name)
  "Return the absolute path of state file NAME."
  (expand-file-name name user-emacs-directory))

(let ((backup-dir (devmacs-state "backup/"))
      (auto-save-dir (devmacs-state "auto-save/")))
  (make-directory backup-dir t)
  (make-directory auto-save-dir t)
  (setq backup-directory-alist `((".*" . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-save-dir t))
        backup-by-copying t
        delete-old-versions t
        version-control t
        kept-new-versions 6
        kept-old-versions 2
        ;; Lock files would litter bind-mounted source trees on the host.
        create-lockfiles nil))

(setq savehist-file (devmacs-state "savehist")
      history-length 1000)
(savehist-mode 1)

(setq recentf-save-file (devmacs-state "recentf")
      recentf-max-saved-items 500
      recentf-exclude (list (regexp-quote (expand-file-name user-emacs-directory))))
(recentf-mode 1)

(setq save-place-file (devmacs-state "places"))
(save-place-mode 1)

(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 100)

(setq require-final-newline t
      sentence-end-double-space nil
      ring-bell-function #'ignore
      use-short-answers t
      confirm-kill-emacs nil
      auto-revert-verbose nil
      ;; Files change underneath a long-lived daemon as a matter of course.
      global-auto-revert-non-file-buffers t)

(global-auto-revert-mode 1)
(delete-selection-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(column-number-mode 1)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'hs-minor-mode)

;; Long lines are especially painful to redraw over a terminal.
(global-so-long-mode 1)

(use-package treesit-auto
  :demand t
  :config
  ;; Grammars are fetched on demand: baking them in would inflate the image for
  ;; languages most projects never touch.
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode))

(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode))

(use-package yaml-mode
  :mode ("\\.ya?ml\\'" . yaml-mode))

(use-package dockerfile-mode
  :mode ("Dockerfile\\'" . dockerfile-mode))

(use-package eat
  :commands (eat eat-project))

(provide 'devmacs-editing)
;;; devmacs-editing.el ends here
