;;; conf-elisp.el --- Emacs Lisp -*- lexical-binding: t -*-

;;; Commentary:

;; Syntax checking goes through `elisp-flymake-byte-compile', the native
;; backend enabled in conf-lsp.el.

;;; Code:

;; Finds a function from an input / output example.
(use-package suggest
  :ensure t
  :commands suggest)

;; Evaluates an expression as you type and shows the result inline.
(use-package litable
  :ensure t
  :commands litable-mode)

(provide 'conf-elisp)

;;; conf-elisp.el ends here
