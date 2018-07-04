(use-package git-gutter-fringe+
  :ensure t)
(global-git-gutter+-mode)

(use-package magit
  :ensure t)
(setq magit-refresh-status-buffer nil)
;; (global-set-key (kbd "C-x g") 'magit-status)
