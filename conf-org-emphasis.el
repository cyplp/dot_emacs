;;; conf-org-emphasis.el --- emphase org sur la region active -*- lexical-binding: t -*-

;;; Commentary:

;; Taper un marqueur d'emphase org alors qu'une region est active encadre cette
;; region avec le marqueur : selectionner "longue phrase" puis taper "*" produit
;; "*longue phrase*".
;;
;; Ce geste n'avait aucun effet utile jusqu'ici : le caractere s'inserait
;; simplement au point et la selection etait perdue. La seule voie restante
;; etait `C-c C-x C-f', qui redemande ensuite le marqueur au minibuffer.
;;
;; Depuis l'activation de `delete-selection-mode' dans init.el, ne rien faire
;; serait pire encore : le marqueur remplacerait purement et simplement le texte
;; selectionne. La commande definie ici n'ayant pas la propriete
;; `delete-selection', elle echappe a ce remplacement et garde la main sur la
;; region.
;;
;; L'encadrement lui-meme est delegue a `org-emphasize' : il sait deja deshabiller
;; une emphase preexistante et poser les espaces de garde qu'impose
;; `org-emphasis-regexp-components'. Ce fichier n'ajoute que ce qui manque autour
;; — le rognage des bords, la detection de contexte et les liaisons de touches.

;;; Code:

(require 'org)
(require 'org-element)

(defconst my-org-emphasis-inert-elements
  '(src-block example-block export-block comment-block comment
    fixed-width latex-environment keyword)
  "Types d'elements org ou le balisage d'emphase n'a aucun sens.
Encadrer une expression dans un bloc de code y injecterait des caracteres
que le langage source interprete, sans jamais produire de mise en forme.")

(defconst my-org-emphasis-boundary-characters " \t\n\r"
  "Caracteres exclus des bords d'une selection avant encadrement.
La grammaire d'org refuse un marqueur adjacent a un blanc : \"*texte *\"
reste du texte brut, marqueurs visibles. Rogner la selection est donc ce
qui fait que l'emphase prend reellement effet.")

(defun my-org-emphasis-inert-context-p (position)
  "Non-nil quand POSITION est dans un contexte org sans emphase possible.
Le contexte est demande a l'analyseur d'org plutot qu'a une expression
reguliere maison, pour rester juste sur les blocs imbriques."
  (memq (org-element-type (org-element-at-point position))
        my-org-emphasis-inert-elements))

(defun my-org-emphasis-region-bounds ()
  "Bornes de la region active ramenees a son contenu non blanc.
Renvoie un cons (DEBUT . FIN), ou nil quand la region ne contient que des
blancs : il n'y a alors rien a encadrer."
  (let ((start (region-beginning))
        (end (region-end)))
    (save-excursion
      (goto-char start)
      (skip-chars-forward my-org-emphasis-boundary-characters end)
      (setq start (point))
      (goto-char end)
      (skip-chars-backward my-org-emphasis-boundary-characters start)
      (setq end (point)))

    (when (< start end)
      (cons start end))))

(defun my-org-emphasize-region-or-self-insert (repetitions)
  "Encadrer la region active avec le marqueur frappe, sinon l'inserer.
REPETITIONS est l'argument prefixe, transmis a `org-self-insert-command'
quand aucun encadrement n'a lieu.

Le repli passe par `org-self-insert-command' et non par
`self-insert-command' : org accroche a sa propre commande le blanchiment
de champ et le realignement des tableaux, que la version globale perdrait."
  (interactive "p")
  (let ((bounds (and (org-region-active-p)
                     (not (my-org-emphasis-inert-context-p (region-beginning)))
                     (my-org-emphasis-region-bounds))))
    (if (null bounds)
        (org-self-insert-command repetitions)

      (set-mark (car bounds))
      (goto-char (cdr bounds))
      (org-emphasize last-command-event))))

(defun my-org-emphasis-bind-markers ()
  "Lier chaque marqueur d'`org-emphasis-alist' dans `org-mode-map'.
La liste de caracteres n'est pas figee ici : personnaliser
`org-emphasis-alist' reste coherent avec les touches actives.

La liaison porte sur `org-mode-map' et non sur la keymap globale : les
modes derives d'org-mode en heritent sans declaration supplementaire, et
les buffers non-org ne sont jamais affectes. Lier le caractere directement
prend le pas sur le remappage `self-insert-command' vers
`org-self-insert-command' pose par org, que la branche sans region rejoue."
  (dolist (emphasis org-emphasis-alist)
    (define-key org-mode-map (car emphasis)
                #'my-org-emphasize-region-or-self-insert)))

(my-org-emphasis-bind-markers)

(provide 'conf-org-emphasis)

;;; conf-org-emphasis.el ends here
