;;; devmacs-commands.el --- devmacs operations -*- lexical-binding: t; -*-

;;; Code:

(defun devmacs--project-root ()
  "Return the current project root, or nil."
  (when-let* ((proj (project-current)))
    (project-root proj)))

;;;###autoload
(defun devmacs-recompile ()
  "Recompile the configuration modules.

Needed when the config is mounted from the host rather than taken from the
image, since the .elc and .eln baked in no longer match the sources."
  (interactive)
  (byte-recompile-directory devmacs-user-lisp-directory 0 t)
  (when (native-comp-available-p)
    (dolist (file (directory-files devmacs-user-lisp-directory t "\\.el\\'"))
      (condition-case err
          (native-compile file)
        (error (message "devmacs: native-compile skipped %s (%S)" file err)))))
  (message "devmacs: recompiled %s" devmacs-user-lisp-directory))

;;;###autoload
(defun devmacs-mise-install ()
  "Run mise install for the current project.

Runtimes are declared per project in mise.toml rather than baked into the
image. What gets installed lands on the shared volume, so the same language at
the same version is instant everywhere afterwards."
  (interactive)
  (let ((default-directory (or (devmacs--project-root) default-directory)))
    (compile "mise install")))

;;;###autoload
(defun devmacs-mise-trust ()
  "Run mise trust for the current project."
  (interactive)
  (let ((default-directory (or (devmacs--project-root) default-directory)))
    (compile "mise trust")))

;;;###autoload
(defun devmacs-env-describe ()
  "Show the project environment applied to the current buffer."
  (interactive)
  (call-interactively #'buffer-env-describe))

(provide 'devmacs-commands)
;;; devmacs-commands.el ends here
