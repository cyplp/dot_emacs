;;; conf-elisp.el --- Emacs Lisp -*- lexical-binding: t -*-

;;; Commentary:

;; La verification syntaxique passe par `elisp-flymake-byte-compile', backend
;; natif active dans conf-lsp.el.

;;; Code:

;; Retrouve une fonction a partir d'un exemple entree / sortie.
(use-package suggest
  :ensure t
  :commands suggest)

;; Evalue une expression au fil de la frappe et affiche le resultat en ligne.
(use-package litable
  :ensure t
  :commands litable-mode)

(provide 'conf-elisp)

;;; conf-elisp.el ends here
