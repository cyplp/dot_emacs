;;; conf-claude.el --- Assistant Claude Code -*- lexical-binding: t -*-

;;; Commentary:

;; Integration du CLI `claude' dans Emacs par claude-code-ide.el.
;;
;; Le paquet ne se limite pas a ouvrir un terminal : il demarre un serveur MCP
;; auquel le CLI se connecte, ce qui donne a Claude l'etat d'Emacs — buffer
;; courant, region selectionnee, diagnostics flymake, resultats xref — et fait
;; passer les propositions de modification par `ediff' au lieu d'un patch
;; affiche dans le terminal.
;;
;; Le paquet est absent de MELPA : il est installe par `:vc', integre a
;; use-package depuis Emacs 30.

;;; Code:

;; --- Terminal ---------------------------------------------------------------

;; Le CLI est une application plein ecran : il lui faut un vrai emulateur de
;; terminal, `shell' ou `comint' ne suffisent pas. `eat' est ecrit en Emacs
;; Lisp pur, la ou `vterm' — backend par defaut du paquet — exige une
;; compilation native (cmake, libtool) absente de cette machine.
(use-package eat
  :ensure t
  :commands (eat eat-mode))

;; --- Claude Code ------------------------------------------------------------

;; Filet de securite : le CLI s'installe dans ~/.local/bin, que le PATH d'un
;; Emacs lance depuis un menu graphique ne contient pas toujours. Meme idiome
;; que pour ~/go/bin dans conf-go.el.
(let ((local-binary-directory (expand-file-name "~/.local/bin")))
  (add-to-list 'exec-path local-binary-directory)
  (setenv "PATH" (concat local-binary-directory path-separator (getenv "PATH"))))

;; Les raccourcis partent de F2 et non de F8 : conf-org.el occupe deja F8,
;; C-F8 et S-F8 pour les captures, et conf-python.el reprend F8 dans
;; python-mode-map. F2 n'a pour role par defaut que le prefixe two-column,
;; inutilise ici.
(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind (("<f2>" . claude-code-ide-menu)
         ;; Affiche ou masque la fenetre de la session sans l'arreter.
         ("<S-f2>" . claude-code-ide-toggle)
         ;; Passe a Claude une reference vers la region ou le fichier courant.
         ("<C-f2>" . claude-code-ide-insert-at-mentioned))
  :custom
  (claude-code-ide-terminal-backend 'eat)
  ;; Le backend recommande en amont, `ghostel', n'est pas installe ici : le
  ;; rappel affiche une fois par session d'Emacs n'apporterait rien.
  (claude-code-ide-show-backend-recommendation nil)
  :config
  ;; Expose a Claude les outils MCP cotes Emacs : xref, imenu, project,
  ;; diagnostics. Sans cet appel le serveur MCP se limite aux notifications de
  ;; selection et au diff par ediff.
  (claude-code-ide-emacs-tools-setup))

;; --- Blocs org --------------------------------------------------------------

;; `ob-claude' fait de `claude' un langage org-babel : le corps du bloc est un
;; prompt, `C-c C-c' l'envoie au CLI et la reponse devient le resultat.
(with-eval-after-load 'org
  (require 'ob-claude)

  ;; Le prompt et la reponse sont du markdown : `org-edit-special' ouvre le
  ;; bloc dans markdown-mode plutot que dans `fundamental-mode'.
  (add-to-list 'org-src-lang-modes '("claude" . markdown))

  ;; `<cl' puis TAB insere le bloc.
  (add-to-list 'org-structure-template-alist '("cl" . "src claude")))

(provide 'conf-claude)

;;; conf-claude.el ends here
