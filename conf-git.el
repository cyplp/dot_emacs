(use-package git-gutter
  :ensure t
  :hook (prog-mode . git-gutter-mode)
  :config
  (setq git-gutter:update-interval 1.0))

(use-package git-gutter-fringe
  :ensure t
  :config
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom))



(use-package magit
  :ensure t)

(setq magit-refresh-status-buffer nil)

;; activate to debug magit-performance
(setq magit-refresh-verbose nil)


(use-package git-messenger
  :ensure t)
;; TODO better shortcut
(global-set-key (kbd "C-x v p") 'git-messenger:popup-message)


(use-package git-modes
  :ensure t)

(use-package gist
  :ensure t)

(use-package forge
  :ensure t
  :after magit)

;; remove some hooks for magit performance-s
(remove-hook 'magit-status-sections-hook 'forge-insert-pullreqs)
(remove-hook 'magit-status-sections-hook 'forge-insert-issues)

;; gitlab stuff
(use-package gitlab-ci-mode
  :ensure t)

(use-package gitlab-ci-mode-flycheck
  :ensure t
  :after flycheck gitlab-ci-mode
  :init
  (gitlab-ci-mode-flycheck-enable))

;; open current line in forge web-page
(use-package browse-at-remote
  :ensure t)

;; better git blame
(use-package vc-msg
  :ensure t)


(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

(quelpa '(conventional-commit
          :fetcher github
          :repo "akirak/conventional-commit.el"))

(use-package conventional-commit
  :ensure nil ;;
  :hook
  (git-commit-mode . conventional-commit-setup))
