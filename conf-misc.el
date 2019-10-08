
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

;; display in powerline number of match in search
(use-package anzu
  :ensure t)
(global-anzu-mode +1)

;; focus on current block
(use-package focus
  :ensure t)

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
  "Insert a newline from anywhare in the line."
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


;; neotree
(use-package neotree
  :ensure t)

(global-set-key [f2] 'neotree-toggle)


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

(provide 'conf-misc)
;;; conf-misc ends here
