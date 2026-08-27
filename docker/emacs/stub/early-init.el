;;; early-init.el --- devmacs stub -*- lexical-binding: t; -*-

;; $HOME/.emacs.d holds state only; the config itself lives read-only at
;; $DEVMACS_CONFIG. Keeping them apart matters because --init-directory moves
;; all of user-emacs-directory, which would drop elpa, eln-cache and history
;; into the config repository.

;;; Code:

(load (expand-file-name "early-init.el"
                        (or (getenv "DEVMACS_CONFIG") "/opt/devmacs/config"))
      nil t)

;;; early-init.el ends here
