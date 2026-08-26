;;; conf-shortcut.el --- Raccourcis globaux -*- lexical-binding: t -*-

;;; Commentary:

;; Raccourcis qui ne dependent d'aucun mode majeur.

;;; Code:

;; Completion par expansion sur le texte deja present dans les buffers.
(global-set-key [S-iso-lefttab] #'dabbrev-expand)
(global-set-key [S-tab] #'dabbrev-expand)
(global-set-key [f9] #'dabbrev-completion)

(global-set-key [f3] #'revert-buffer)

;; `kill-this-buffer' est declaree obsolete depuis Emacs 29 : hors d'un menu
;; elle ne fait rien de fiable, faute de savoir quelle fenetre l'a appelee.
(global-set-key [f4] #'kill-current-buffer)

(global-set-key [f5] #'comment-region)
(global-set-key (kbd "<S-f5>") #'uncomment-region)

;; Diagnostic sous le curseur, cote flymake (flycheck a ete retire).
(global-set-key [f12] #'flymake-show-buffer-diagnostics)

(global-set-key (kbd "C-z") #'undo)
(global-set-key (kbd "M-g") #'goto-line)

;; Recherche du symbole sous le curseur.
(global-set-key (kbd "C-S-s") #'isearch-forward-symbol-at-point)

(provide 'conf-shortcut)

;;; conf-shortcut.el ends here
