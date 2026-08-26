;;; conf-lsp.el --- Serveurs de langage et diagnostics -*- lexical-binding: t -*-

;;; Commentary:

;; Un seul client LSP : eglot, integre a Emacs depuis la version 29.  Il
;; remplace lsp-mode et lsp-ui, qui faisaient double emploi avec lui langage
;; par langage — python et rust d'un cote, go de l'autre — avec deux jeux de
;; reglages, deux frontaux de completion et deux systemes de diagnostics a
;; maintenir en parallele.
;;
;; Un seul systeme de diagnostics, egalement : flymake, natif lui aussi et
;; deja alimente par eglot.  flycheck et ses six greffons faisaient tourner
;; des sous-processus supplementaires pour produire, dans les modes pilotes
;; par un serveur de langage, exactement les memes erreurs.
;;
;; Les modules par langage se contentent d'appeler `eglot-ensure' ; tout ce
;; qui est commun est ici.

;;; Code:

(require 'eglot)

;; Le buffer d'evenements journalise chaque message JSON echange avec le
;; serveur. Sur un projet actif cela represente plusieurs mega-octets par
;; session, formates a chaque insertion. Inutile hors debogage du protocole.
(setq eglot-events-buffer-config '(:size 0 :format full))

;; Plafonne la duree d'un gel quand un serveur ne repond pas (defaut : 30 s).
(setq eglot-request-timeout 10)

;; Ne bloque pas le demarrage d'Emacs en attendant la poignee de main :
;; au-dela d'une seconde la connexion se poursuit en arriere-plan.
(setq eglot-sync-connect 1)

;; Arrete le serveur avec le dernier buffer du projet, au lieu de laisser
;; tourner un gopls ou un rust-analyzer par projet visite dans la session.
(setq eglot-autoshutdown t)

;; Permet a `xref' de suivre une definition hors du projet courant, typiquement
;; dans la bibliotheque standard ou les dependances.
(setq eglot-extend-to-xref t)

;; Reglages transmis aux serveurs. La forme plist est celle attendue par eglot
;; depuis Emacs 29 ; l'ancienne forme alist reste acceptee mais est obsolete.
(setq-default eglot-workspace-configuration
              '(:gopls (:staticcheck t
                        :matcher "CaseSensitive"
                        :usePlaceholders t)
                :rust-analyzer (:check (:command "clippy")
                                :cargo (:buildScripts (:enable t))
                                :procMacro (:enable t))))

;; Note sur Python : `eglot-server-programs' essaie deja, dans l'ordre, pylsp,
;; basedpyright, pyright, jedi-language-server puis "ruff server". Aucun n'a
;; besoin d'etre declare ici. Seul ruff est installe sur cette machine, ce qui
;; donne le formatage et le lint mais ni completion ni types : installer
;; basedpyright ou pylsp suffirait a obtenir le reste.

;; --- Diagnostics ------------------------------------------------------------

(use-package flymake
  :hook (emacs-lisp-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)
              ("C-c ! p" . flymake-show-project-diagnostics))
  :custom
  ;; Le fanion dans la marge suffit ; le soulignement ondule rend illisibles
  ;; les longues lignes deja colorees.
  (flymake-fringe-indicator-position 'left-fringe)
  (flymake-no-changes-timeout 0.7))

;; shellcheck est le seul backend flymake utile pour les scripts shell. Sans
;; le binaire, activer flymake ne produirait qu'un avertissement de backend
;; en echec a chaque ouverture de fichier.
(when (executable-find "shellcheck")
  (add-hook 'sh-mode-hook #'flymake-mode)
  (add-hook 'bash-ts-mode-hook #'flymake-mode))

(provide 'conf-lsp)

;;; conf-lsp.el ends here
