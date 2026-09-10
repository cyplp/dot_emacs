;;; conf-latex.el --- LaTeX -*- lexical-binding: t -*-

;;; Commentary:

;; AUCTeX and its navigation shortcuts.

;;; Code:

(use-package auctex
  :ensure t
  :defer t)

(use-package latex-extra
  :ensure t
  :hook (LaTeX-mode . latex-extra-mode))

(provide 'conf-latex)

;;; conf-latex.el ends here
