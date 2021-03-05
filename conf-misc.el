
;; french calendar
(defvar calendar-day-name-array
  ["dim" "lun" "mar" "mer" "jeu" "ven" "sam"])
(defvar calendar-month-name-array
  ["janvier" "février" "mars" "avril" "mai" "juin"
   "juillet" "août" "septembre" "octobre" "novembre" "décembre"])

;; short anwser
(fset 'yes-or-no-p 'y-or-n-p)

(defun increment-number-at-point ()
      (interactive)
      (skip-chars-backward "0-9")
      (or (looking-at "[0-9]+")
          (error "No number at point"))
      (replace-match (number-to-string (1+ (string-to-number (match-string 0)))
				       )
		     )
      )
(global-set-key (kbd "C-+") 'increment-number-at-point)


(defun kill-start-of-line()
  "kill from point to start of line"
  (interactive)
  (kill-line 0)
  )

(global-set-key  (kbd "M-k") 'kill-start-of-line)


(use-package ctrlf
  :ensure t
  :commands (ctrf-mode))

(use-package ssh-config-mode
  :ensure t
  :commands (ssh-config-mode)
  )

(add-to-list 'auto-mode-alist '("/\\.ssh/config\\'"     . ssh-config-mode))
(add-to-list 'auto-mode-alist '("/sshd?_config\\'"      . ssh-config-mode))
(add-to-list 'auto-mode-alist '("/known_hosts\\'"       . ssh-known-hosts-mode))
(add-to-list 'auto-mode-alist '("/authorized_keys2?\\'" . ssh-authorized-keys-mode))
(add-hook 'ssh-config-mode-hook 'turn-on-font-lock)

;;graphviz-dot-mode
(use-package graphviz-dot-mode
  :ensure t)
					;
;;flycheck-color-mode-line-mode
(use-package flycheck-color-mode-line
  :ensure t)
(add-hook 'flycheck-mode-hook 'flycheck-color-mode-line-mode)

(use-package auto-complete-rst
  :ensure t)

(eval-after-load "rst" '(auto-complete-rst-init))

(use-package restclient
  :ensure t)

(use-package restclient-helm
  :ensure t)

(use-package jq-mode
  :ensure t)

;; colorize color in hexa
(use-package rainbow-mode
  :ensure t
  :commands rainbow-mode)


;; move selection
(use-package move-text
 :ensure t)
(move-text-default-bindings)
(global-set-key [M-up] 'move-text-up)
(global-set-key [M-down] 'move-text-down)

;;iedit
(use-package iedit
  :ensure t
  :commands iedit-mode)

;;highlight-indent-guides
(use-package highlight-indent-guides
  :ensure t)

(add-hook 'prog-mode-hook 'highlight-indent-guides-mode)
(setq highlight-indent-guides-method 'character)


;; set parenthe in color
(use-package highlight-parentheses
  :ensure t)

(add-hook 'prog-mode-hook 'highlight-parentheses-mode)

;; fold stuff
(use-package origami
  :ensure t)

;; better minibuffer explanation
;; buuildin emacs
;;(require 'icomplete)
;;(icomplete-mode 1)

;; blink on cursor
(use-package beacon
  :ensure t
  :commands beacon-mode)

;; plantuml stuff
(use-package plantuml-mode
  :ensure t)
(use-package flycheck-plantuml
  :ensure t)

(with-eval-after-load 'flycheck
  (require 'flycheck-plantuml)
  ;; Enable plantuml-mode for PlantUML files
  (add-to-list 'auto-mode-alist '("\\.plantuml\\'" . plantuml-mode))
  (flycheck-plantuml-setup))

;; more colors !
(use-package color-identifiers-mode
  :ensure t)
(color-identifiers-mode t)
(add-hook 'after-init-hook 'global-color-identifiers-mode)

;; search on google
;;(use-package heml-google
;;  :ensure t)

;;powerline
(use-package spaceline
  :ensure t)
(require 'spaceline-config)
(spaceline-emacs-theme)

;; (use-package spaceline-all-the-icons
;;   :after spaceline
;;   :config (spaceline-all-the-icons-theme))


;; quick search in docs
(use-package helm-dash
  :ensure t)

;;emms
;; from https://www.reddit.com/r/emacs/comments/981khz/emacs_music_player_with_emms/e4cnhzi/
(use-package emms
  :ensure t
  :config
  (emms-all)
  (emms-default-players)
  (setq emms-playlist-buffer-name "*Music*")
  (setq emms-info-asynchronously t)
  (setq emms-source-file-default-directory "~/musique/")
  (require 'emms-info-libtag) ;;; load functions that will talk to emms-print-metadata which in turn talks to libtag and gets metadata
  (setq emms-info-functions '(emms-info-libtag)) ;;; make sure libtag is the only thing delivering metadata
  (require 'emms-mode-line)
  (emms-mode-line 1)
  (require 'emms-playing-time)
  (emms-playing-time 1)
  )


;; lorem ipsum
(use-package lorem-ipsum
  :ensure t)

;; goto EOL and newline and indent
(defun eol-newline-indent ()
  "Insert a newline from anywhere in the line."
  (interactive)
  (end-of-line)
  (newline-and-indent))

(global-set-key (kbd "M-<return>") 'eol-newline-indent)

;; helm-ls-git
(use-package helm-ls-git
  :ensure t)

;; helm-ag
(use-package helm-ag
  :ensure t)

;; cheat.sh see http://cheat.sh/
(use-package cheat-sh
  :ensure t)

;; weather toy
(use-package wttrin
  :ensure t)

(setq wttrin-default-accept-language '("Accept-Language" . "fr-FR"))
(setq wttrin-default-cities '("tls"))


;; pocket
(use-package pocket-reader
  :ensure t)

;; list on the side
(use-package imenu-list
  :ensure t)
(global-set-key [f1] 'imenu-list-smart-toggle)


;; from https://www.emacswiki.org/emacs/DuplicateLines
(defun uniquify-region-lines (beg end)
  "Remove duplicate adjacent lines in region."
  (interactive "*r")
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "^\\(.*\n\\)\\1+" end t)
      (replace-match "\\1"))))

(defun uniquify-buffer-lines ()
 "Remove duplicate adjacent lines in the current buffer."
 (interactive)
 (uniquify-region-lines (point-min) (point-max)))


;; edit a region in a second buffer
(use-package edit-indirect
  :ensure t)

;; engine mode
(use-package engine-mode
  :ensure t)

(engine-mode t)
(defengine amazon
  "http://www.amazon.com/s/ref=nb_sb_noss?url=search-alias%3Daps&field-keywords=%s")

(defengine duckduckgo
  "https://duckduckgo.com/?q=%s"
  :keybinding "d")

(defengine github
  "https://github.com/search?ref=simplesearch&q=%s")

(defengine google
  "http://www.google.fr/search?ie=utf-8&oe=utf-8&q=%s"
  :keybinding "g")

(defengine google-images
  "http://www.google.com/images?hl=en&source=hp&biw=1440&bih=795&gbv=2&aq=f&aqi=&aql=&oq=&q=%s")

(defengine google-maps
  "http://maps.google.com/maps?q=%s"
  :docstring "Mappin' it up.")

(defengine project-gutenberg
  "http://www.gutenberg.org/ebooks/search/?query=%s")

(defengine rfcs
  "http://pretty-rfc.herokuapp.com/search?q=%s")

(defengine stack-overflow
  "https://stackoverflow.com/search?q=%s")

(defengine twitter
  "https://twitter.com/search?q=%s")

(defengine wikipedia
  "http://www.wikipedia.org/search-redirect.php?language=fr&go=Go&search=%s"
  :keybinding "w"
  :docstring "Searchin' the wikis.")

(defengine wiktionary
  "https://www.wikipedia.org/search-redirect.php?family=wiktionary&language=fr&go=Go&search=%s")

(defengine wolfram-alpha
  "http://www.wolframalpha.com/input/?i=%s")

(defengine youtube
  "http://www.youtube.com/results?aq=f&oq=&search_query=%s")

;; undo-tree
(use-package undo-tree
  :ensure t)
(global-set-key (kbd "C-x :") 'undo-tree-visualize)

;; unicode help
(use-package helm-unicode
  :ensure t)

;; hl current buffer
(use-package dimmer
  :ensure t)
(dimmer-mode)

;; keyfreq
(use-package keyfreq
  :ensure t
  :config
  (require 'keyfreq)
  (keyfreq-mode 1)
  (keyfreq-autosave-mode 1)
  )

;; see https://editorconfig.org/
(use-package editorconfig
  :ensure t
  :config
  (editorconfig-mode 1))


;; c-sharp
(use-package csharp-mode
  :ensure t)

;; hl stuf
(use-package highlight-symbol
  :ensure t
    :init (progn  (add-hook 'prog-mode-hook 'highlight-symbol-mode)
                  (add-hook 'prog-mode-hook 'highlight-symbol-nav-mode)))

;; uuid generator
;; copy from https://nullprogram.com/blog/2010/05/11/
(defun uuid-create ()
  "Return a newly generated UUID. This uses a simple hashing of variable data."
  (let ((s (md5 (format "%s%s%s%s%s%s%s%s%s%s"
                        (user-uid)
                        (emacs-pid)
                        (system-name)
                        (user-full-name)
                        user-mail-address
                        (current-time)
                        (emacs-uptime)
                        (garbage-collect)
                        (random)
                        (recent-keys)))))
    (format "%s-%s-3%s-%s-%s"
            (substring s 0 8)
            (substring s 8 12)
            (substring s 13 16)
            (substring s 16 20)
            (substring s 20 32))))

(defun uuid-insert ()
  "Inserts a new UUID at the point."
  (interactive)
  (insert (uuid-create)))

;; remind binding
(use-package remind-bindings
  :ensure t
  :hook (after-init . remind-bindings-initialise)
  :bind (("C-c C-d" . 'remind-bindings-toggle-buffer)   ;; toggle buffer
         ("C-c M-d" . 'remind-bindings-specific-mode))) ;; buffer-specific only


;; smoth-scrolling
(use-package smooth-scrolling
  :ensure t)
(smooth-scrolling-mode 1)

;; tldr
(use-package tldr
  :ensure t)

;; ibuffer
(use-package ibuffer-git
  :ensure t)
(use-package ibuffer-vc
  :ensure t)
(use-package ibuffer-tramp
  :ensure t)


(global-set-key (kbd "C-x C-b") 'ibuffer)
;; lua
(use-package lua-mode
  :ensure t)

;; sudo-edit
(use-package sudo-edit
  :ensure t)

;; shell interface
(use-package multi-term
  :ensure t)

;; eradio
(use-package eradio
  :ensure t)

(global-set-key (kbd "C-c r p") 'eradio-play)
(global-set-key (kbd "C-c r s") 'eradio-stop)

(setq eradio-channels '(("fip" . "https://stream.radiofrance.fr/fip/fip_hifi.m3u8?id=radiofrance")))

(defun play-fip ()
  (interactive)
  (eradio--play-low-level "https://stream.radiofrance.fr/fip/fip_hifi.m3u8?id=radiofrance"))

(global-set-key (kbd "C-c r f") 'play-fip)


(use-package whitespace-cleanup-mode
  :ensure t)

(global-whitespace-cleanup-mode t)
(provide 'conf-misc)
;;; conf-misc ends here
