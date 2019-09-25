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


;; menu for connecting to db
(use-package helm-sql-connect
  :ensure t)

;; by pass https://github.com/eric-hansen/helm-sql-connect/issues/3
(defvar helm-sql-connection-pool helm-sql-connect-pool)

;; read db connection
(setq db_connections "~/.emacs.d/dbconnections.el")
(if (file-exists-p db_connections)
    (load db_connections))


(defun sql-beautiful-after (word)
   (while (search-forward-regexp word nil t)
     (replace-match (format "\\1%s\n" word)
		    )))

(defun sql-beautiful-before (word)
   (while (search-forward-regexp word nil t)
     (replace-match (format "\n\\1%s" word)
		    )))


(defun sql-beautiful-region (start-pos end-pos)
  "Beautiful SQL."
  (interactive "r")
  (save-excursion
    (sqlup-capitalize-keywords-in-region start-pos end-pos)
    (goto-char 1)

    (mapc 'sql-beautiful-after '("," "JOIN" "AND"))
    (mapc 'sql-beautiful-before '("FROM" "WHERE"))

     (indent-region start-pos end-pos))
    (message "Ah, much better!"))


(provide 'conf-sql)
;;; conf-sql ends here
