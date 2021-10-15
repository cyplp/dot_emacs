(use-package rust-mode
  :ensure t)

(use-package flycheck-rust
  :ensure t)

(with-eval-after-load 'rust-mode
  (add-hook 'flycheck-mode-hook #'flycheck-rust-setup))

;; completion and doc
(use-package racer
  :ensure t)
(add-hook 'rust-mode-hook #'racer-mode)
(add-hook 'racer-mode-hook #'eldoc-mode)

;; cargo
(use-package cargo
  :ensure t)
(add-hook 'rust-mode-hook 'cargo-minor-mode)

(use-package cargo-mode
  :ensure t
  :config
  (add-hook 'rust-mode-hook 'cargo-minor-mode))

(define-key rust-mode-map (kbd "C-c b") 'cargo-mode-build)
