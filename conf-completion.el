;;; conf-completion.el --- In-buffer completion -*- lexical-binding: t -*-

;;; Commentary:

;; Split of roles: helm owns the minibuffer (M-x, files, buffers), corfu owns
;; completion at point in the buffer.  They do not step on each other because
;; `helm-mode-handle-completion-in-region' is disabled in init.el.
;;
;; corfu relies on `completion-at-point-functions', the standard Emacs
;; interface: eglot, dabbrev and the major modes feed it without a dedicated
;; plugin.  That is what replaces auto-complete and company, both previously
;; present through satellite packages (auto-complete-rst, auto-complete-nxml).

;;; Code:

(use-package corfu
  :ensure t
  :custom
  ;; Automatic trigger: without it corfu only shows up on
  ;; `completion-at-point', which amounts to typing the shortcut every time.
  (corfu-auto t)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.15)
  (corfu-cycle t)
  ;; Do not complete on exit by default: an unwanted insertion at the slightest
  ;; cursor move costs more than a missed completion.
  (corfu-preview-current nil)
  (corfu-quit-no-match 'separator)
  :init
  (global-corfu-mode 1)
  :config
  ;; Documentation of the current candidate in a side tooltip.
  (corfu-popupinfo-mode 1))

;; dabbrev is the fallback source in buffers without a language server.
;; By default it walks image and archive buffers, which produces binary
;; candidates.
(use-package dabbrev
  :custom
  (dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\|gz\\|zip\\)\\'")))

(provide 'conf-completion)

;;; conf-completion.el ends here
