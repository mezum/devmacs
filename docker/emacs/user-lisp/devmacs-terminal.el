;;; devmacs-terminal.el --- terminal integration -*- lexical-binding: t; -*-

;; The Cmd key never reaches Emacs here: the terminal emulator keeps it. That
;; is the point - it leaves Ctrl and Meta as the only modifiers on both macOS
;; and Windows, so the mac-command-modifier split that GUI Emacs suffers from
;; simply does not exist. Sending Option/Alt as Meta is handled on the terminal
;; side, in wezterm/wezterm.lua.

;;; Code:

;; The host clipboard is invisible from inside a container, so writes go out
;; over OSC 52 and the terminal puts them where they belong.
(defun devmacs-osc52-copy (text &optional _push)
  "Send TEXT to the host clipboard using OSC 52."
  (when (and (stringp text) (not (string-empty-p text)))
    (let* ((b64 (base64-encode-string (encode-coding-string text 'utf-8) t))
           (seq (concat "\e]52;c;" b64 "\a")))
      (send-string-to-terminal
       ;; tmux swallows the sequence unless it is wrapped for passthrough
       ;; (which also needs allow-passthrough on the tmux side).
       (if (getenv "TMUX")
           (concat "\ePtmux;" (string-replace "\e" "\e\e" seq) "\e\\")
         seq)))))

(setq interprogram-cut-function #'devmacs-osc52-copy
      ;; Reading the clipboard over OSC 52 is refused by most terminals, so
      ;; pasting is left to the terminal's own bracketed paste.
      interprogram-paste-function nil
      select-enable-clipboard t
      select-enable-primary nil)

;; Emacs 31 enables this on terminals it recognises, but the detection misses
;; some, so say it out loud.
(when (fboundp 'xterm-mouse-mode)
  (xterm-mouse-mode 1))
(setq mouse-wheel-scroll-amount '(3 ((shift) . 1))
      mouse-wheel-progressive-speed nil)

(setq-default truncate-lines nil)

;; The window title belongs to the terminal, not to a container.
(setq xterm-set-window-title nil)

(provide 'devmacs-terminal)
;;; devmacs-terminal.el ends here
