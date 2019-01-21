
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
(use-package emms
  :ensure t)

;; lorem ipsum
(use-package lorem-ipsum
  :ensure t)

;; goto EOL and newline and indent
(defun eol-newline-indent ()
  (interactive)
  (end-of-line)
  (newline-and-indent))

;; helm-ls-git
(use-package helm-ls-git
  :ensure t)
