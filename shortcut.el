;; code completion
(global-set-key (quote [S-iso-lefttab]) (quote dabbrev-expand))
(global-set-key (quote [S-tab]) (quote dabbrev-expand))
(global-set-key (quote [f9]) (quote dabbrev-completion))


;; redéfinition de quelques touches

(global-set-key [f1] 'fill-region)
(global-set-key [f2] 'auto-fill-mode)

(global-set-key [f3] 'revert-buffer)
(global-set-key [f4] 'kill-this-buffer)
(global-set-key [f5] 'comment-region)
(global-set-key [f7] 'uncomment-region)
(global-set-key [f8] 'indent-region)
(global-set-key [f12] 'flymake-display-err-menu-for-current-line)
(global-set-key [delete] 'delete-char)
;;(global-set-key [home] 'beginning-of-buffer)
;;(global-set-key [end] 'end-of-buffer)
(global-set-key [(control z)] `undo)

(global-set-key "\M-g" 'goto-line)
(global-set-key (quote [C-return]) 'nxml-complete)

(global-set-key (kbd "C-x g") 'magit-status)