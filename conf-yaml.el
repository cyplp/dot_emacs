;;; conf-yaml.el --- YAML -*- lexical-binding: t -*-

;;; Commentary:

;; Les fichiers .yaml et .yml passent par `yaml-ts-mode' (conf-treesit.el).
;; Le paquet `yaml-mode' reste installe : `docker-compose-mode', `k8s-mode' et
;; `ansible' en derivent leurs propres modes majeurs.

;;; Code:

(use-package yaml-mode
  :ensure t
  :defer t)

;; Mode dedie aux specifications OpenAPI 3, absent de MELPA.
;; `:vc' remplace l'appel a quelpa, qui interrogeait le depot distant a chaque
;; demarrage d'Emacs.
(use-package openapi-yaml-mode
  :vc (:url "https://github.com/magoyette/openapi-yaml-mode" :rev :newest)
  :commands openapi-yaml-mode)

(provide 'conf-yaml)

;;; conf-yaml.el ends here
