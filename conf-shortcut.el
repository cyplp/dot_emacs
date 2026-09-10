;;; conf-shortcut.el --- Global shortcuts -*- lexical-binding: t -*-

;;; Commentary:

;; Shortcuts that depend on no major mode.

;;; Code:

;; Expansion completion over the text already present in the buffers.
(global-set-key [S-iso-lefttab] #'dabbrev-expand)
(global-set-key [S-tab] #'dabbrev-expand)
(global-set-key [f9] #'dabbrev-completion)

(global-set-key [f3] #'revert-buffer)

;; `kill-this-buffer' is obsolete since Emacs 29: outside a menu it does
;; nothing reliable, as it cannot know which window called it.
(global-set-key [f4] #'kill-current-buffer)

(global-set-key [f5] #'comment-region)
(global-set-key (kbd "<S-f5>") #'uncomment-region)

;; Diagnostic under point, on the flymake side (flycheck was dropped).
(global-set-key [f12] #'flymake-show-buffer-diagnostics)

(global-set-key (kbd "C-z") #'undo)
(global-set-key (kbd "M-g") #'goto-line)

;; Search for the symbol under point.
(global-set-key (kbd "C-S-s") #'isearch-forward-symbol-at-point)

(provide 'conf-shortcut)

;;; conf-shortcut.el ends here
