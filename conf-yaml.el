;;; conf-yaml.el --- YAML -*- lexical-binding: t -*-

;;; Commentary:

;; .yaml and .yml files go through `yaml-ts-mode' (conf-treesit.el).
;; The `yaml-mode' package stays installed: `docker-compose-mode', `k8s-mode'
;; and `ansible' derive their own major modes from it.

;;; Code:

(use-package yaml-mode
  :ensure t
  :defer t)

;; Mode dedicated to OpenAPI 3 specifications, absent from MELPA.
;; `:vc' replaces the quelpa call, which queried the remote repository on
;; every Emacs startup.
(use-package openapi-yaml-mode
  :vc (:url "https://github.com/magoyette/openapi-yaml-mode" :rev :newest)
  :commands openapi-yaml-mode)

(provide 'conf-yaml)

;;; conf-yaml.el ends here
