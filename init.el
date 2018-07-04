(require 'package)
;;(add-to-list 'package-archives
;;'("marmalade" . "http://marmalade-repo.org/packages/"))

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/")))


(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
	(package-refresh-contents)
	(package-install 'use-package))

(use-package try
  :ensure t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

;; theme
(use-package tangotango-theme
  :ensure t)

;; no splash screen
(setq inhibit-splash-screen t)

;; window title
(setq frame-title-format `(buffer-file-name "Emacs %d %f" "emacs %d"))

;; display line and colum
(setq column-number-mode t)
(setq line-number-mode t)
