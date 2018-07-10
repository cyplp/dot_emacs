
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
  :init (ssh-config-mode t)
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

(use-package rainbow-mode
  :ensure t
  :init (rainbow-mode t))

;; move selection
(use-package move-text
 :ensure t)
(move-text-default-bindings)
(global-set-key [M-up] 'move-text-up)
(global-set-key [M-down] 'move-text-down)
