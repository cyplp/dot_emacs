(require 'package)
(add-to-list 'package-archives
	     '("marmalade" . "http://marmalade-repo.org/packages/"))

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/")))

(add-to-list 'package-archives
             '("org" . "http://orgmode.org/elpa/"))

(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
	(package-refresh-contents)
	(package-install 'use-package))


;; reduce the frequency of garbage collection by making it happen on
;; each 50MB of allocated data (the default is on every 0.76MB)
(setq gc-cons-threshold 50000000)

;; warn when opening files bigger than 100MB
(setq large-file-warning-threshold 100000000)

(use-package try
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
(show-paren-mode t )

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
(global-set-key (kbd "C-²") 'er/expand-region)

(use-package yasnippet
  :ensure t
  :init
  (yas-global-mode 1))

;; (use-package auto-indent-mode
;;   :ensure t
;;   :init (auto-indent-global-mode))
;; (setq auto-indent-indent-style 'conservative)

;; save custom in separete file
;; thanks to https://github.com/bdejean
(setq custom-file "~/.emacs.d/custom.el")
(if (file-exists-p custom-file)
    (load custom-file))

;; org-stuff
(load-file "~/.emacs.d/conf-org.el")

;; misc
(load-file "~/.emacs.d/conf-misc.el")

;; secret stuff
(setq secret-file "~/.emacs.d/secret.el")
(if (file-exists-p secret-file)
    (load secret-file))

;; python
(load-file "~/.emacs.d/conf-python.el")

;; git
(load-file "~/.emacs.d/conf-git.el")

;; shortcut
(load-file "~/.emacs.d/shortcut.el")

;; auto load mode
(load-file "~/.emacs.d/conf-auto-load.el")

;; jabber.el
(load-file "~/.emacs.d/conf-jabber.el")

;; some nxml stuff
(load-file "~/.emacs.d/conf-xml.el")

;; rust
(load-file "~/.emacs.d/conf-rust.el")

;;sql
(load-file "~/.emacs.d/conf-sql.el")

;;web
(load-file "~/.emacs.d/conf-web.el")

;; thinkpad stuff
(load-file "~/.emacs.d/thinkpad.el")

;; dired stuff
(load-file "~/.emacs.d/conf-dired.el")

;; elisp stuff
(load-file "~/.emacs.d/conf-elisp.el")

;; load old stuff from old .emacs
;; migrating from old to here
;; not in git
(setq old-file "~/.emacs.d/old.el")
(if (file-exists-p old-file)
    (load old-file))

(message "conf loaded")
