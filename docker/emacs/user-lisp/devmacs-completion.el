;;; devmacs-completion.el --- completion -*- lexical-binding: t; -*-

;;; Code:

(use-package vertico
  :demand t
  :config
  (setq vertico-cycle t
        vertico-count 15)
  (vertico-mode 1))

(use-package orderless
  :demand t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :demand t
  :config (marginalia-mode 1))

(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x p b" . consult-project-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-s l"   . consult-line)
         ("M-s r"   . consult-ripgrep)
         ("M-s f"   . consult-fd))
  :config
  (setq consult-narrow-key "<"
        register-preview-delay 0.2
        xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

(defcustom devmacs-use-corfu-terminal (< emacs-major-version 31)
  "Use corfu-terminal instead of child frames.
Emacs 31 runs child frames on a TTY, so corfu works as-is; set this when a
terminal cannot handle them."
  :type 'boolean
  :group 'devmacs)

(use-package corfu
  :demand t
  :config
  (setq corfu-auto t
        corfu-auto-delay 0.2
        corfu-auto-prefix 2
        corfu-cycle t
        corfu-quit-no-match 'separator
        corfu-preselect 'prompt)
  (global-corfu-mode 1)
  (corfu-history-mode 1)
  (corfu-popupinfo-mode 1))

(use-package corfu-terminal
  :if devmacs-use-corfu-terminal
  :demand t
  :after corfu
  :config (corfu-terminal-mode 1))

(use-package cape
  :demand t
  :config
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-dabbrev))

(setq completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t)

(provide 'devmacs-completion)
;;; devmacs-completion.el ends here
