;;; devmacs-user.el --- user configuration layer -*- lexical-binding: t; -*-

;; The base configuration ships inside the image, so anything a user adds has
;; to live outside it or every image update would wipe it. ee mounts a host
;; directory read-only and points DEVMACS_USER_CONFIG at it, which also means
;; the user config can be kept in its own repository.

;;; Code:

(defconst devmacs-user-config-directory
  (or (getenv "DEVMACS_USER_CONFIG") "/opt/devmacs/user")
  "Where the user's own configuration is mounted.")

(defvar devmacs-user-packages nil
  "Packages requested by the user configuration.
Set this in packages.el inside `devmacs-user-config-directory'.")

(defun devmacs-user--file (name)
  "Return NAME under the user config directory if it is readable."
  (let ((path (expand-file-name name devmacs-user-config-directory)))
    (and (file-readable-p path) path)))

(defun devmacs-user--read-declaration ()
  "Load the user's package declaration."
  (when-let* ((path (devmacs-user--file "packages.el")))
    (load path nil t)))

;;;###autoload
(defun devmacs-user-load ()
  "Load the user configuration on top of the base one."
  (when (file-directory-p devmacs-user-config-directory)
    (let ((user-lisp (expand-file-name "user-lisp" devmacs-user-config-directory)))
      (when (file-directory-p user-lisp)
        (add-to-list 'load-path user-lisp)))
    (when-let* ((path (devmacs-user--file "init.el")))
      (load path nil t))))

;;;###autoload
(defun devmacs-user-install ()
  "Install the packages declared by the user configuration.

Deliberately not run at startup: checking on every launch would slow the daemon
down and undo the point of compiling everything at build time. What is
installed lands on the state volume, so it survives image updates."
  (interactive)
  (devmacs-user--read-declaration)
  (if (null devmacs-user-packages)
      (message "devmacs: no packages declared in %s"
               devmacs-user-config-directory)
    (require 'package)
    (package-initialize)
    (let ((installed 0))
      (dolist (pkg devmacs-user-packages)
        (unless (package-installed-p pkg)
          (unless (assq pkg package-archive-contents)
            (package-refresh-contents))
          (message "devmacs: installing %s" pkg)
          (package-install pkg)
          (setq installed (1+ installed))))
      ;; In batch this is the only chance to compile; a running daemon can
      ;; leave it to JIT.
      (when (and noninteractive (native-comp-available-p))
        (dolist (pkg devmacs-user-packages)
          (when-let* ((desc (cadr (assq pkg package-alist)))
                      (dir (package-desc-dir desc)))
            (dolist (file (directory-files-recursively dir "\\.el\\'"))
              (condition-case err
                  (native-compile file)
                (error
                 (message "devmacs: native-compile skipped %s (%S)" file err)))))))
      (message "devmacs: %d package(s) installed" installed))))

(provide 'devmacs-user)
;;; devmacs-user.el ends here
