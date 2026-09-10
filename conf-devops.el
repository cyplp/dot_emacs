;;; conf-devops.el --- Containers, orchestration, infrastructure -*- lexical-binding: t -*-

;;; Commentary:

;; Docker, Ansible, Kubernetes, Terraform.
;;
;; Dockerfiles are handled by `dockerfile-ts-mode' (conf-treesit.el), which
;; makes the `dockerfile-mode' package useless.  `marcopolo' — a Docker Hub
;; client — and `docker-explorer' were dropped: both are unmaintained since
;; 2016 and the `docker' package covers the same ground.

;;; Code:

;; --- Docker -----------------------------------------------------------------

(use-package docker
  :ensure t
  :bind ("C-c d" . docker))

(use-package docker-compose-mode
  :ensure t
  ;; The pattern also covers "compose.yaml", the name kept by Compose v2, and
  ;; the override files. It must also differ from the package autoload:
  ;; `add-to-list' ignores an entry identical to an existing one, so that a
  ;; verbatim declaration stayed behind the general .yaml pattern of
  ;; conf-treesit.el and never applied.
  :mode ("\\(?:\\`\\|/\\)\\(?:docker-\\)?compose[^/]*\\.ya?ml\\'" . docker-compose-mode)
  :bind (:map docker-compose-mode-map
              ("C-c C-c" . docker-compose)
              ("C-c C-u" . docker-compose-up)
              ("C-c C-w" . docker-compose-down)
              ("C-c C-r" . docker-compose-restart)))

;; --- Ansible ----------------------------------------------------------------

(use-package ansible
  :ensure t
  ;; `ansible' is declared obsolete since 2024 in favour of `ansible-mode'.
  :commands ansible-mode)

(use-package ansible-doc
  :ensure t
  :commands ansible-doc)

(use-package ansible-vault
  :ensure t
  :commands ansible-vault-mode)

;; --- Kubernetes -------------------------------------------------------------

(use-package k8s-mode
  :ensure t
  :commands k8s-mode)

(use-package kubernetes
  :ensure t
  :commands (kubernetes-overview))

(use-package kubernetes-helm
  :ensure t
  :after kubernetes)

;; --- Terraform --------------------------------------------------------------

(use-package terraform-mode
  :ensure t
  :mode ("\\.tf\\(?:vars\\)?\\'" . terraform-mode))

(use-package terraform-doc
  :ensure t
  :commands terraform-doc)

(provide 'conf-devops)

;;; conf-devops.el ends here
