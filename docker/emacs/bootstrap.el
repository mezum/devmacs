;;; bootstrap.el --- bake packages into the image -*- lexical-binding: t; -*-

;; Invoked from the Dockerfile as
;;   emacs --batch --init-directory=/opt/devmacs/seed -l .../bootstrap.el
;;
;; Installing and natively compiling here means no machine pays for it on first
;; start. The output is a seed rather than $HOME/.emacs.d because the state
;; volume mounted there at runtime would hide it. eln-cache is architecture
;; specific, so this assumes CI builds one image per architecture.

;;; Code:

(let ((config-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path config-dir)
  (load (expand-file-name "packages.el" config-dir) nil t)

  ;; JIT is off during install so that compilation happens synchronously at the
  ;; end; otherwise --batch exits before the async workers have produced eln.
  (setq native-comp-jit-compilation nil
        native-comp-async-report-warnings-errors nil
        byte-compile-warnings nil)

  (require 'package)
  (setq package-archives
        '(("gnu"    . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
          ("melpa"  . "https://melpa.org/packages/")))
  (package-initialize)
  (package-refresh-contents)

  (dolist (pkg devmacs-packages)
    (unless (package-installed-p pkg)
      (message "devmacs: installing %s" pkg)
      (package-install pkg)))

  (dolist (spec devmacs-vc-packages)
    (let ((pkg (car spec))
          (url (cdr spec)))
      (unless (package-installed-p pkg)
        (message "devmacs: installing %s from %s" pkg url)
        (package-vc-install url (symbol-name pkg)))))

  ;; The user-lisp/ auto-compilation added in Emacs 31 only covers directories
  ;; under user-emacs-directory, and devmacs keeps its config elsewhere.
  (let ((user-lisp (expand-file-name "user-lisp" config-dir)))
    (when (file-directory-p user-lisp)
      (add-to-list 'load-path user-lisp)
      (byte-recompile-directory user-lisp 0 t)))

  (when (native-comp-available-p)
    (let ((targets (list (expand-file-name "user-lisp" config-dir)
                         package-user-dir))
          (count 0))
      (dolist (dir targets)
        (when (file-directory-p dir)
          (dolist (file (directory-files-recursively dir "\\.el\\'"))
            ;; Compiling fixtures buys nothing and some of them fail on purpose.
            (unless (string-match-p "/\\(tests?\\|examples?\\)/" file)
              (condition-case err
                  (progn (native-compile file)
                         (setq count (1+ count)))
                (error
                 (message "devmacs: native-compile skipped %s (%S)" file err)))))))
      (message "devmacs: native-compiled %d files" count)))

  (let ((stub-dir (expand-file-name "stub" config-dir)))
    (dolist (f '("early-init.el" "init.el"))
      (copy-file (expand-file-name f stub-dir)
                 (expand-file-name f user-emacs-directory)
                 t)))

  (message "devmacs: bootstrap done (seed=%s)" user-emacs-directory))

;;; bootstrap.el ends here
