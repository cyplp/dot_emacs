;; docker stuff
(use-package docker
  :ensure t)

(use-package dockerfile-mode
  :ensure t)

(use-package docker-compose-mode
  :ensure t)

;; launch docker-compose menu, up and down
(define-key docker-compose-mode-map (kbd "C-c C-c") 'docker-compose)
(define-key docker-compose-mode-map (kbd "C-c C-u") 'docker-compose-up)
(define-key docker-compose-mode-map (kbd "C-c C-w") 'docker-compose-down)
(define-key docker-compose-mode-map (kbd "C-c C-r") 'docker-compose-restart)

(use-package marcopolo
  :ensure t)

;; docker-explorer
(quelpa '(docker-explorer
	  :fetcher git
	  :url "https://gitlab.com/ndw/docker-explorer.git"))



;; ansible
(use-package ansible
  :ensure t)

(use-package ansible-doc
  :ensure t)

(use-package ansible-vault
  :ensure t)


;; kubernetes
(use-package k8s-mode
  :ensure t)

(use-package kubernetes
  :ensure t
  :commands (kubernetes-overview))

(use-package kubernetes-helm
  :ensure t)

;; logstash
(use-package logstash-conf-mode
  :ensure t)
