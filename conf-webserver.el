;;; conf-webserver.el --- Configuration des serveurs web -*- lexical-binding: t -*-

;;; Commentary:

;; Modes majeurs pour les fichiers de configuration nginx et Caddy.

;;; Code:

(use-package nginx-mode
  :ensure t
  :mode (("nginx\\.conf\\'" . nginx-mode)
         ("/nginx/.*\\.conf\\'" . nginx-mode)))

(use-package caddyfile-mode
  :ensure t
  :mode (("Caddyfile\\'" . caddyfile-mode)
         ("caddy\\.conf\\'" . caddyfile-mode)))

(provide 'conf-webserver)

;;; conf-webserver.el ends here
