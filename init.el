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
(ido-everywhere 1)
(use-package ido-yes-or-no
  :ensure t)
(ido-yes-or-no-mode 1)
(ido-mode 1)

;; clipboard
(setq x-select-enable-clipboard t)

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

(use-package auto-indent-mode
  :ensure t
  :init (auto-indent-global-mode))

;; org-stuff
(load-file "conf-org.el")

;; misc
(load-file "conf-misc.el")

;; secret stuff
(load-file "secret.el")

;; python
(load-file "conf-python.el")

;; git
(load-file "conf-git.el")

;; shortcut
(load-file "shortcut.el")

;; auto load mode
(load-file "conf-auto-load.el")

;; jabber.el
(load-file "conf-jabber.el")

;; some nxml stuff
(load-file "conf-xml.el")

;; rust
(load-file "conf-rust.el")

;;sql
(load-file "conf-sql.el")


;;web
(load-file "conf-web.el")

;; load old stuff from old .emacs
;; migrating from old to here
;; not in git
(load-file "old.el")
