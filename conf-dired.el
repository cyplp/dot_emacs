;;; conf-dired.el --- Navigation dans les fichiers -*- lexical-binding: t -*-

;;; Commentary:

;; Reglages du gestionnaire de fichiers integre.
;;
;; `image-dired+' a ete retire : la generation asynchrone des vignettes qu'il
;; apportait est native depuis Emacs 29.  `dired-icon' aussi : il faisait
;; exactement le meme travail qu'`all-the-icons-dired', et les deux poses
;; d'icones se superposaient sur chaque ligne.

;;; Code:

(use-package dired
  :custom
  ;; Groupe les repertoires en tete, tailles lisibles, tri naturel des nombres.
  (dired-listing-switches "-alhv --group-directories-first")
  ;; Avec deux fenetres dired ouvertes, propose l'autre comme destination par
  ;; defaut d'une copie ou d'un deplacement.
  (dired-dwim-target t)
  ;; Reutilise le buffer courant au lieu d'en ouvrir un par repertoire
  ;; traverse, qui s'accumulaient jusqu'a saturer la liste des buffers.
  (dired-kill-when-opening-new-dired-buffer t)
  ;; Recursion sans confirmation pour les copies ; la suppression reste
  ;; confirmee.
  (dired-recursive-copies 'always))

(use-package all-the-icons-dired
  :ensure t
  :hook (dired-mode . all-the-icons-dired-mode))

(provide 'conf-dired)

;;; conf-dired.el ends here
