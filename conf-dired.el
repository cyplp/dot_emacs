;; thumbs in dired
(use-package image-dired+
  :ensure t)
(eval-after-load 'image-dired '(require 'image-dired+))
(eval-after-load 'image-dired+ '(image-diredx-async-mode 1))

;; icons
(use-package dired-icon
  :ensure t)
(add-hook 'dired-mode-hook 'dired-icon-mode)

(use-package all-the-icons-dired
  :ensure t)
(add-hook 'dired-mode-hook 'all-the-icons-dired-mode)
