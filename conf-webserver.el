;;; conf-webserver.el --- Web server configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Major modes for nginx and Caddy configuration files.

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
