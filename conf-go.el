;;; conf-go.el --- Configuration Go -*- lexical-binding: t -*-

;;; Commentary:

;; `go-ts-mode', integre a Emacs 30, remplace le paquet MELPA `go-mode'.
;; Ce dernier n'est plus maintenu et son analyse par expressions regulieres
;; decroche sur les generiques introduits en Go 1.18.
;;
;; go-mode fournissait aussi `gofmt-before-save'.  Cette fonction ne s'active
;; que si `major-mode' vaut exactement `go-mode' : conservee telle quelle, elle
;; n'aurait plus jamais formate un seul fichier apres la bascule.  Le formatage
;; passe donc par `reformatter', deja utilise pour XML dans cette configuration.

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

;; Emacs (surtout en GUI) n'herite pas du PATH du shell : eglot ne trouve donc
;; pas gopls dans ~/go/bin. On recupere le PATH du shell de connexion.
(use-package exec-path-from-shell
  :ensure t
  :config
  (when (or (memq window-system '(mac ns x pgtk))
            (daemonp))
    (exec-path-from-shell-initialize)))

;; Filet de securite : ~/go/bin dans exec-path et PATH meme sans le shell.
(let ((go-binary-directory (expand-file-name "~/go/bin")))
  (add-to-list 'exec-path go-binary-directory)
  (setenv "PATH" (concat go-binary-directory path-separator (getenv "PATH"))))

;; goimports formate ET reorganise les imports en un seul sous-processus court,
;; la ou l'action de code LSP "source.organizeImports" attend la reponse de
;; gopls en bloquant Emacs a chaque sauvegarde.
;;
;; L'option -srcdir donne a goimports le repertoire du fichier : sans elle il
;; travaille sur un flux anonyme et ne peut pas resoudre les imports du module
;; courant, ce qui lui fait supprimer des imports pourtant valides.
(reformatter-define go-format
  :program "goimports"
  :args (list "-srcdir" (or (buffer-file-name) default-directory)))

(defun my-go-setup ()
  "Reglages communs aux buffers Go."
  (eglot-ensure)
  (go-format-on-save-mode 1)
  ;; Go impose des tabulations ; la largeur d'affichage reste une preference.
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 4))

(add-hook 'go-ts-mode-hook #'my-go-setup)

;; gopls sert aussi go.mod : completion des versions de modules et diagnostics
;; sur les directives require / replace.
(add-hook 'go-mod-ts-mode-hook #'eglot-ensure)

(with-eval-after-load 'go-ts-mode
  (setq go-ts-mode-indent-offset 4))

;; Les reglages gopls (staticcheck, matcher) sont dans conf-lsp.el, avec le
;; reste de la configuration eglot.

(provide 'conf-go)

;;; conf-go.el ends here
