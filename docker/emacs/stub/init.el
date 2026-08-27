;;; init.el --- devmacs stub -*- lexical-binding: t; -*-

;; See stub/early-init.el for why the real config is elsewhere.

;;; Code:

(load (expand-file-name "init.el"
                        (or (getenv "DEVMACS_CONFIG") "/opt/devmacs/config"))
      nil t)

;;; init.el ends here
