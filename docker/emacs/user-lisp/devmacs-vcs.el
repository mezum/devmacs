;;; devmacs-vcs.el --- version control -*- lexical-binding: t; -*-

;;; Code:

(use-package magit
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-save-repository-buffers 'dontask
        magit-diff-refine-hunk 'all))

;; Signed commits need the gpg-agent socket forwarded into the container; ee
;; only forwards SSH_AUTH_SOCK today. See "Not there yet" in the README.

(provide 'devmacs-vcs)
;;; devmacs-vcs.el ends here
