(use-package db-pg
  :ensure t)

(use-package sql-indent
  :ensure t)

(eval-after-load "sql"
  '(load-library "sql-indent"))
