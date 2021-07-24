;;; init.el --- -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/") t))

(add-to-list 'package-archives
             '("org" . "https://orgmode.org/elpa/") t)

;; avoid old .elc
(setq load-prefer-newer t)
(setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")

(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
	(package-refresh-contents)
	(package-install 'use-package))

;; reduce the frequency of garbage collection by making it happen on
;; each 50MB of allocated data (the default is on every 0.76MB)
(setq gc-cons-threshold 5000000)

(setq make-backup-files nil) ; stop creating backup~ files
(setq auto-save-default nil) ; stop creating #autosave# files
(setq create-lockfiles nil)  ; stop creating .# files

;; warn when opening files bigger than 100MB
(setq large-file-warning-threshold 100000000)

;; Turn Off Cursor Alarms
;; from https://github.com/MatthewZMD/.emacs.d
(setq ring-bell-function 'ignore)

;; limit message buffer size
(setq-default message-log-max 100)

(use-package try
  :ensure t)

;; quelpa : non melpa package
(use-package quelpa
  :ensure t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

;;smex
(use-package smex
  :ensure t)
(smex-initialize)

(global-set-key (kbd "M-x") 'smex)
(global-set-key (kbd "M-X") 'smex-major-mode-commands)
;; This is your old M-x.
(global-set-key (kbd "C-c C-c M-x") 'execute-extended-command)

;; paradox : better pacage manager
;; github token is in secret.el
(use-package paradox
  :ensure t)

;; theme
(use-package tangotango-theme
  :ensure t)

(load-theme 'tangotango t)

;; no splash screen
(setq inhibit-splash-screen t)

;; window title
(setq frame-title-format `(buffer-file-name "Emacs %d %f" "emacs %d"))

;; remove menu-bar
(menu-bar-mode 0)

;; remove menu-bar
(tool-bar-mode 0)

;; display line and colum
(setq column-number-mode t)
(setq line-number-mode t)

;; utf-8
(prefer-coding-system 'mule-utf-8)

;; move mouse cursor
(mouse-avoidance-mode 'animate)

;; display only tails of lines longer than 80 columns, tabs and
;; trailing whitespaces
(setq whitespace-line-column 88
      whitespace-style '(tabs trailing lines-tail))

;; nuke trailing whitespaces when writing to a file
(add-hook 'write-file-functions 'delete-trailing-whitespace)

;; pretty-icons
(use-package mode-icons
  :ensure t
  :config
  (mode-icons-mode))

;; ace-window
(use-package ace-window
  :ensure t
  :init
  (progn
    (global-set-key [remap other-window] 'ace-window)
    (custom-set-faces
     '(aw-leading-char-face
       ((t (:inherit ace-jump-face-foreground :height 3.0)))))
    ))

;; add line a EOF
(setq require-final-newline t)

;; just one line
(setq next-line-add nil)

;; activate ido-mode
(setq ido-enable-flex-matching t)

;;(ido-everywhere 1)
(use-package ido-yes-or-no
  :ensure t)
(ido-yes-or-no-mode 1)
(ido-mode 1)

;; clipboard
(setq select-enable-clipboard t)

;; xclip
(use-package xclip
  :ensure t
  :config
  (xclip-mode 1))

;; see the other parent
(show-paren-mode t)

;;winner mode
(winner-mode t)

;; automatic pair
(setq skeleton-pair t)
(global-set-key "[" 'skeleton-pair-insert-maybe)
(global-set-key "{" 'skeleton-pair-insert-maybe)
(global-set-key "(" 'skeleton-pair-insert-maybe)
(global-set-key "\"" 'skeleton-pair-insert-maybe)


(use-package auto-complete
  :ensure t
  :init
  (progn
    (ac-config-default)
    (global-auto-complete-mode t)
    ))

(use-package expand-region
  :ensure t)
(global-set-key (kbd "C-œ") 'er/expand-region)


;; string inflection use in some yassnippet
(use-package string-inflection
  :ensure t)
(require 'string-inflection)


;; yasnippets
(use-package yasnippet
  :ensure t
  :init
  (yas-global-mode 1)
  :config (use-package yasnippet-snippets
	    :ensure t)
          (use-package aws-snippets
	   :ensure t)
	  (yas-reload-all))

;; Helm
(use-package helm
  :ensure t
  :init
  (setq helm-M-x-fuzzy-match t
	helm-mode-fuzzy-match t
	helm-buffers-fuzzy-matching t
	helm-recentf-fuzzy-match t
	helm-locate-fuzzy-match t
	helm-semantic-fuzzy-match t
	helm-imenu-fuzzy-match t
	helm-completion-in-region-fuzzy-match t
	helm-candidate-number-list 150
	helm-split-window-in-side-p t
	helm-move-to-line-cycle-in-source t
	helm-echo-input-in-header-line t
	helm-autoresize-max-height 0
	helm-autoresize-min-height 20)
  :config
  (helm-mode 1))

;; tramp default method
(setq tramp-default-method "ssh")

;; (use-package auto-indent-mode
;;   :ensure t
;;   :init (auto-indent-global-mode))
;; (setq auto-indent-indent-style 'conservative)

;; save custom in separete file
;; thanks to https://github.com/bdejean
(setq custom-file "~/.emacs.d/custom.el")
(if (file-exists-p custom-file)
    (load custom-file))

(setq to-load '(;; org-stuff
		"~/.emacs.d/conf-org.el"
		;; misc
		"~/.emacs.d/conf-misc.el"
		"~/.emacs.d/conf-python.el"
		"~/.emacs.d/conf-git.el"
		"~/.emacs.d/shortcut.el"
		"~/.emacs.d/conf-auto-load.el"
		"~/.emacs.d/conf-jabber.el"
		"~/.emacs.d/conf-xml.el"
		"~/.emacs.d/conf-rust.el"
		"~/.emacs.d/conf-sql.el"
		"~/.emacs.d/conf-web.el"
		"~/.emacs.d/thinkpad.el"
		"~/.emacs.d/conf-dired.el"
		"~/.emacs.d/conf-elisp.el"
		"~/.emacs.d/conf-yaml.el"
		"~/.emacs.d/conf-devops.el"
		"~/.emacs.d/conf-latex.el"
		"~/.emacs.d/conf-webserver.el"
		;; secret stuff such as passwords
		"~/.emacs.d/secret.el"))

(defun load-local-file (file)
  "Load a local file.
FILE is the file to load."
  (if (file-exists-p file)
      (load-file file)))

(mapc 'load-local-file to-load)

;; load old stuff from old .emacs
;; migrating from old to here
;; not in git
(setq old-file "~/.emacs.d/old.el")
(if (file-exists-p old-file)
    (load old-file))

(message "conf loaded")
