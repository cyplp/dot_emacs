;;; conf-conventional-commit.el --- coloration des messages conventional commits -*- lexical-binding: t -*-

;;; Commentary:

;; Coloration syntaxique du prefixe Conventional Commits dans les tampons de
;; message de commit ouverts par magit :
;;
;;   type(portee)!: resume
;;
;; Le paquet `conventional-commit' deja installe ne fournit que la completion du
;; type et de la portee ; rien ne distingue visuellement le prefixe du resume, ni
;; ne signale un type hors liste. C'est ce que ce module ajoute.
;;
;; La liste des types reconnus n'est pas redefinie ici : elle est lue dans
;; `conventional-commit-type-list', pour que completion et coloration ne puissent
;; pas diverger.
;;
;; Les motifs sont poses avec le drapeau OVERRIDE : git-commit colore deja toute
;; la ligne de resume avec la face `git-commit-summary', et sans ce drapeau nos
;; faces seraient simplement ignorees sur cette portion.

;;; Code:

(require 'conventional-commit)

(defface my-conventional-commit-type
  '((t :inherit font-lock-keyword-face))
  "Face du type quand il figure dans `conventional-commit-type-list'."
  :group 'git-commit)

(defface my-conventional-commit-unknown-type
  '((t :inherit font-lock-warning-face))
  "Face du type absent de `conventional-commit-type-list'.
Un type hors liste est refuse par les outils qui lisent l'historique
\(generation de changelog, calcul de version\) : le signaler pendant la
redaction evite d'avoir a reecrire le message apres coup."
  :group 'git-commit)

(defface my-conventional-commit-scope
  '((t :inherit font-lock-function-name-face))
  "Face de la portee, entre parentheses apres le type."
  :group 'git-commit)

(defface my-conventional-commit-breaking
  '((t :inherit error :weight bold))
  "Face du marqueur de rupture de compatibilite.
Couvre le \"!\" du prefixe et le pied de message \"BREAKING CHANGE:\"."
  :group 'git-commit)

(defconst my-conventional-commit-breaking-footer-regexp
  "^\\(BREAKING[ -]CHANGE\\)!?:"
  "Motif du pied de message declarant une rupture de compatibilite.
Les deux graphies sont admises par la specification.")

(defun my-conventional-commit-header-regexp ()
  "Motif du prefixe conventional commit sur la ligne de resume.
Le motif est construit a l'appel et non fige dans une constante : le
caractere de commentaire vient de `core.commentchar' et n'est connu que
dans le tampon, une fois git-commit installe."
  (concat
   ;; La ligne de resume n'est pas toujours la premiere du tampon : git y laisse
   ;; parfois des lignes vides ou des commentaires. On saute la meme entete que
   ;; `git-commit-summary-regexp', pour ne colorer que le vrai resume et jamais
   ;; une ligne du corps qui contiendrait deux points.
   (format "\\`\\(?:^\\(?:\\s-*\\|%s.*\\)\n\\)*" (regexp-quote comment-start))
   "\\([[:alnum:]]+\\)"                 ; type
   "\\(?:(\\([^)\n]+\\))\\)?"           ; portee facultative
   "\\(!\\)?"                           ; marqueur de rupture facultatif
   ":"))

(defun my-conventional-commit-type-face ()
  "Face a appliquer au type qui vient d'etre reconnu.
Appelee par font-lock avec les donnees de correspondance du motif d'entete
encore en place : le type est donc lu dans le groupe 1."
  (if (member (match-string 1) conventional-commit-type-list)
      'my-conventional-commit-type
    'my-conventional-commit-unknown-type))

(defun my-conventional-commit-font-lock-keywords ()
  "Motifs font-lock du format conventional commits pour le tampon courant."
  (list
   (list (my-conventional-commit-header-regexp)
         '(1 (my-conventional-commit-type-face) t)
         '(2 'my-conventional-commit-scope t t)
         '(3 'my-conventional-commit-breaking t t))

   (list my-conventional-commit-breaking-footer-regexp
         '(1 'my-conventional-commit-breaking t))))

(defun my-conventional-commit-setup-font-lock ()
  "Ajouter la coloration conventional commits au tampon de message courant.
Les motifs sont ajoutes en queue de liste : ceux de git-commit passent
d'abord et notre prefixe se pose par dessus le resume."
  (font-lock-add-keywords nil (my-conventional-commit-font-lock-keywords) t)
  (font-lock-flush))

;; `git-commit-setup' lie `git-commit-mode-hook' a nil le temps d'activer le mode
;; mineur : un reglage accroche la n'est jamais joue lors d'un commit lance par
;; magit. `git-commit-setup-hook' est le point d'entree prevu, et il passe apres
;; `git-commit-setup-font-lock' : la liste de motifs de git-commit est donc deja
;; posee quand on y ajoute les notres.
(add-hook 'git-commit-setup-hook #'my-conventional-commit-setup-font-lock)

(provide 'conf-conventional-commit)

;;; conf-conventional-commit.el ends here
