;;; conf-devops.el --- Conteneurs, orchestration, infrastructure -*- lexical-binding: t -*-

;;; Commentary:

;; Docker, Ansible, Kubernetes, Terraform.
;;
;; Les Dockerfile sont pris en charge par `dockerfile-ts-mode' (conf-treesit.el),
;; ce qui rend le paquet `dockerfile-mode' inutile.  `marcopolo' — client du
;; Docker Hub — et `docker-explorer' ont ete retires : tous deux sont sans
;; maintenance depuis 2016 et le paquet `docker' couvre le meme terrain.

;;; Code:

;; --- Docker -----------------------------------------------------------------

(use-package docker
  :ensure t
  :bind ("C-c d" . docker))

(use-package docker-compose-mode
  :ensure t
  ;; Le motif englobe aussi "compose.yaml", nom retenu par Compose v2, et
  ;; les fichiers d'override. Il doit par ailleurs differer de l'autoload du
  ;; paquet : `add-to-list' ignore une entree identique a une entree existante,
  ;; si bien qu'une declaration a l'identique restait derriere le motif .yaml
  ;; general de conf-treesit.el et ne s'appliquait jamais.
  :mode ("\\(?:\\`\\|/\\)\\(?:docker-\\)?compose[^/]*\\.ya?ml\\'" . docker-compose-mode)
  :bind (:map docker-compose-mode-map
              ("C-c C-c" . docker-compose)
              ("C-c C-u" . docker-compose-up)
              ("C-c C-w" . docker-compose-down)
              ("C-c C-r" . docker-compose-restart)))

;; --- Ansible ----------------------------------------------------------------

(use-package ansible
  :ensure t
  ;; `ansible' est declaree obsolete depuis 2024 au profit d'`ansible-mode'.
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
