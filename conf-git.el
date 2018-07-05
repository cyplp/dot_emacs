(use-package git-gutter-fringe+
  :ensure t)
(global-git-gutter+-mode)

(use-package magit
  :ensure t)
(setq magit-refresh-status-buffer nil)

(add-hook 'magit-status-mode-hook 'magit-filenotify-mode)

(use-package git-messenger
  :ensure t)
;; TODO better shortcut
(global-set-key (kbd "C-x v p") 'git-messenger:popup-message)
