;;; early-init.el --- devmacs early init -*- lexical-binding: t; -*-

;; Only things that have to be decided before frames and the package system
;; come up belong here.

;;; Code:

;; Raised for startup and put back at the end of init.el.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Everything shipped is already AOT compiled, so JIT only ever runs for
;; packages the user adds later; its warnings are not worth a screen.
(setq native-comp-async-report-warnings-errors 'silent)

;; This is a nox build, so nothing GUI-derived should be created at all.
(setq default-frame-alist '((menu-bar-lines . 0)
                            (tool-bar-lines . 0)
                            (vertical-scroll-bars . nil))
      frame-inhibit-implied-resize t
      inhibit-startup-screen t
      initial-scratch-message nil
      inhibit-x-resources t)

(setq package-enable-at-startup nil)

;;; early-init.el ends here
