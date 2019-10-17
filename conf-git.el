(use-package git-gutter-fringe+
  :ensure t)
(global-git-gutter+-mode)

(use-package magit
  :ensure t)
(setq magit-refresh-status-buffer nil)

(use-package magit-filenotify
  :ensure t)
(add-hook 'magit-status-mode-hook 'magit-filenotify-mode)

(use-package git-messenger
  :ensure t)
;; TODO better shortcut
(global-set-key (kbd "C-x v p") 'git-messenger:popup-message)

(use-package gitignore-mode
  :ensure t)

(use-package gitconfig-mode
  :ensure t)

(use-package gist
  :ensure t)

;; (use-package forge
;;   :ensure t
;;   :after magit)

;; gitlab stuff
(use-package gitlab-ci-mode
  :ensure t)

(use-package gitlab-ci-mode-flycheck
  :ensure t
  :after flycheck gitlab-ci-mode
  :init
  (gitlab-ci-mode-flycheck-enable))
