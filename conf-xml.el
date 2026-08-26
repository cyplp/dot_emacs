;;; conf-xml.el --- XML et nXML -*- lexical-binding: t -*-

;;; Commentary:

;; `auto-complete-nxml' a ete retire : auto-complete n'est plus maintenu et la
;; completion dans le buffer passe desormais par corfu (conf-completion.el),
;; qui consomme directement les candidats de nxml via
;; `completion-at-point-functions'.
;;
;; Le formatage etait declare deux fois : une fois par `reformatter-define'
;; ici, une fois par le paquet MELPA `xml-format', qui n'est rien d'autre que
;; le meme appel. Seule la definition locale subsiste.

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

(use-package nxml-mode
  :mode (("\\.xml\\'" . nxml-mode)
         ("\\.xsl\\'" . nxml-mode)
         ("\\.zcml\\'" . nxml-mode)
         ("\\.plist\\'" . nxml-mode)
         ("\\.pt\\'" . nxml-mode))
  :bind (:map nxml-mode-map
              ("C-c h" . hs-toggle-hiding)
              ;; Liaison deplacee depuis la keymap globale, ou elle rendait
              ;; C-<return> inutilisable dans tous les autres modes.
              ;; `nxml-complete' est obsolete depuis Emacs 26 : la completion
              ;; passe par `completion-at-point', donc par corfu, qui recupere
              ;; les memes candidats issus du schema RELAX NG.
              ("C-<return>" . completion-at-point))
  :custom
  (nxml-child-indent 2)
  (nxml-attribute-indent 2)
  ;; Ferme la balise des l'ouverture du chevron fermant.
  (nxml-slash-auto-complete-flag t))

;; Schemas HTML5 pour la validation nXML.
(use-package html5-schema
  :ensure t)

;; Navigation par chemin dans un document structure (XML, JSON).
(use-package x-path-walker
  :ensure t
  :commands (helm-x-path-walker))

;; --- Repliage ---------------------------------------------------------------

;; hideshow ne connait pas la syntaxe XML : on lui decrit les delimiteurs.
;; Voir https://emacs.stackexchange.com/questions/2884/
(with-eval-after-load 'hideshow
  (add-to-list 'hs-special-modes-alist
               '(nxml-mode
                 "<!--\\|<[^/>]*[^/]>"
                 "-->\\|</[^/>]*[^/]>"
                 "<!--"
                 sgml-skip-tag-forward
                 nil)))

(add-hook 'nxml-mode-hook #'hs-minor-mode)

;; --- Formatage --------------------------------------------------------------

;; `:mode' est laisse a sa valeur par defaut : c'est lui qui fait engendrer
;; `xml-format-on-save-mode' par la macro. Le passer a nil supprimait ce mode,
;; et le hook plus bas ne survivait que grace au paquet MELPA `xml-format', qui
;; definissait le meme symbole.
(reformatter-define xml-format
  :program "xmllint"
  :args '("--format" "-"))

(add-hook 'nxml-mode-hook #'xml-format-on-save-mode)

(provide 'conf-xml)

;;; conf-xml.el ends here
