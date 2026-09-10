;;; conf-dired.el --- File navigation -*- lexical-binding: t -*-

;;; Commentary:

;; Settings for the built-in file manager.
;;
;; `image-dired+' was dropped: the asynchronous thumbnail generation it added
;; is native since Emacs 29.  `dired-icon' too: it did exactly the same job as
;; `all-the-icons-dired', and both icon overlays stacked on every line.

;;; Code:

(use-package dired
  :custom
  ;; Directories first, readable sizes, natural sort of numbers.
  (dired-listing-switches "-alhv --group-directories-first")
  ;; With two dired windows open, offer the other one as the default
  ;; destination of a copy or a move.
  (dired-dwim-target t)
  ;; Reuse the current buffer instead of opening one per directory visited,
  ;; which piled up until the buffer list was saturated.
  (dired-kill-when-opening-new-dired-buffer t)
  ;; Recursion without confirmation for copies; deletion still asks.
  (dired-recursive-copies 'always))

(use-package all-the-icons-dired
  :ensure t
  :hook (dired-mode . all-the-icons-dired-mode))

(provide 'conf-dired)

;;; conf-dired.el ends here
