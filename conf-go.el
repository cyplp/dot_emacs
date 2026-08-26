;;; conf-go.el --- Go configuration -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; Emacs (surtout en GUI) n'hérite pas du PATH du shell : eglot ne trouve
;; donc pas gopls dans ~/go/bin. On récupère le PATH du shell de connexion.
(use-package exec-path-from-shell
  :ensure t
  :config
  (when (or (memq window-system '(mac ns x pgtk))
            (daemonp))
    (exec-path-from-shell-initialize)))

;; Filet de sécurité : ~/go/bin dans exec-path et PATH même sans le shell.
(let ((gobin (expand-file-name "~/go/bin")))
  (add-to-list 'exec-path gobin)
  (setenv "PATH" (concat gobin path-separator (getenv "PATH"))))

;; go-mode + eglot
;; goimports formate ET reorganise les imports en un seul sous-processus
;; court, la ou eglot-code-actions "source.organizeImports" attendait la
;; reponse de gopls en bloquant Emacs a chaque sauvegarde.
(setq gofmt-command "goimports")

(use-package go-mode
  :ensure t
  :hook ((go-mode . eglot-ensure)
         (before-save . gofmt-before-save)))

;; Complétion avec corfu (optionnel mais confortable)
(use-package corfu
  :ensure t
  :hook (prog-mode . corfu-mode))

;; Navigation erreurs
(use-package flymake
  :bind (:map prog-mode-map
         ("M-n" . flymake-goto-next-error)
         ("M-p" . flymake-goto-prev-error)))

;; Global
;; Plafonne la duree d'un gel si gopls ne repond pas (defaut : 10 s).
(setq eglot-request-timeout 3)

(setq-default eglot-workspace-configuration
  '((:gopls . ((staticcheck . t)
               (matcher . "CaseSensitive")))))

;; eglot est intégré à Emacs (>= 29), inutile de l'installer via use-package.
;; Le bloc précédent contenait la coquille "elgot" qui échouait à chaque démarrage.

(provide 'conf-go)
;;; conf-go.el ends here
