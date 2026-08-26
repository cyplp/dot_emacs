;;; conf-auto-load.el --- Association fichiers / modes majeurs -*- lexical-binding: t -*-

;;; Commentary:

;; Associations qui n'appartiennent a aucun module de langage.
;;
;; Les motifs sont ancres en "\\'" (fin de chaine) et non en "$" (fin de
;; ligne), et le point y est echappe.  Les anciens motifs du type "\.pl$"
;; etaient lus par Emacs comme "n'importe quel caractere, puis pl" : un
;; fichier nomme "toto-xpl" ou "script.tpl" ouvrait en cperl-mode.

;;; Code:

;; cperl-mode est plus complet que perl-mode et le remplace partout.
;; `major-mode-remap-alist' est la forme prevue pour cela depuis Emacs 29 ;
;; l'ancien `defalias' sur `perl-mode' redefinissait la fonction elle-meme,
;; ce qui empeche tout code appelant explicitement `perl-mode' de l'obtenir.
(add-to-list 'major-mode-remap-alist '(perl-mode . cperl-mode))

(add-to-list 'auto-mode-alist '("\\.pl\\'" . cperl-mode))
(add-to-list 'auto-mode-alist '("\\.pm\\'" . cperl-mode))

(add-to-list 'auto-mode-alist '("\\.sql\\'" . sql-mode))
(add-to-list 'auto-mode-alist '("\\.java\\'" . java-mode))
(add-to-list 'auto-mode-alist '("\\.rst\\'" . rst-mode))
(add-to-list 'auto-mode-alist '("\\.cfg\\'" . conf-mode))
(add-to-list 'auto-mode-alist '("\\.ini\\'" . conf-mode))

;; La liaison globale de RET sur `newline-and-indent' a ete retiree :
;; `electric-indent-mode' est actif par defaut depuis Emacs 24.4 et produit le
;; meme effet, sans ecraser les RET propres au minibuffer, aux buffers de
;; commit ou aux modes qui detournent la touche.

(provide 'conf-auto-load)

;;; conf-auto-load.el ends here
