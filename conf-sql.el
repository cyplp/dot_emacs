(use-package db-pg
  :ensure t)

(use-package sql-indent
  :ensure t)

(eval-after-load "sql"
  '(load-library "sql-indent"))


;; upper case sql
(use-package sqlup-mode
  :ensure t)

(global-set-key (kbd "C-c u") 'sqlup-capitalize-keywords-in-region)

(add-hook 'sql-mode-hook 'sqlup-mode)
(add-hook 'sql-interactive-mode-hook 'sqlup-mode)
