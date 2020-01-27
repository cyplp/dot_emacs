(use-package auctex
  :ensure t)

(use-package latex-extra
  :ensure t)

(add-hook 'LaTeX-mode-hook #'latex-extra-mode)
