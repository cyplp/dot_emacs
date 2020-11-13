;; nginx
(use-package nginx-mode
  :ensure t)

;; caddy
(use-package caddyfile-mode
  :ensure t
  :mode (("Caddyfile\\'" . caddyfile-mode)
         ("caddy\\.conf\\'" . caddyfile-mode)))
