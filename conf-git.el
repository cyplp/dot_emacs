(use-package git-gutter-fringe+
  :ensure t)
(global-git-gutter+-mode)

(use-package magit
  :ensure t)
(setq magit-refresh-status-buffer nil)

(add-hook 'magit-status-mode-hook 'magit-filenotify-mode)
