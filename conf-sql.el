;;; conf-sql.el --- SQL -*- lexical-binding: t -*-

;;; Commentary:

;; SQL editing, database connections and query formatting.
;;
;; `db-pg' was dropped: the package is unmaintained since 2013 and pulled in
;; two dependencies (`db', `pg') for a PostgreSQL client that `sql-postgres'
;; covers natively.

;;; Code:

(use-package sql-indent
  :ensure t
  :hook (sql-mode . sqlind-minor-mode))

;; Uppercases SQL keywords as you type.
(use-package sqlup-mode
  :ensure t
  :hook ((sql-mode . sqlup-mode)
         (sql-interactive-mode . sqlup-mode))
  :bind ("C-c u" . sqlup-capitalize-keywords-in-region))

;; Selection menu for a saved connection.
(use-package helm-sql-connect
  :ensure t
  :commands helm-sql-connect
  :config
  ;; Workaround for https://github.com/eric-hansen/helm-sql-connect/issues/3:
  ;; the package reads a variable of which it only defines the homonym.
  (defvar helm-sql-connection-pool helm-sql-connect-pool))

;; The connections themselves live in dbconnections.el, outside the repository;
;; init.el loads it along with the other private files.

;; --- Formatting -------------------------------------------------------------

(defconst sql-beautiful-break-after '("," "JOIN" "AND")
  "Keywords after which the query breaks to a new line.")

(defconst sql-beautiful-break-before '("FROM" "WHERE")
  "Keywords before which the query breaks to a new line.")

(defun sql-beautiful--break (keyword newline-position)
  "Insert a line break around each occurrence of KEYWORD.
NEWLINE-POSITION is `after' or `before', depending on which side the break
goes.

The search is bounded by the limits of the region narrowed by the caller.
Alphabetic keywords are delimited with `\\b' so as not to cut an identifier
that contains them, such as the \"BRAND\" column for AND.  The comma cannot
be: `\\b' marks a boundary between a word and a non-word character, and
therefore never finds one around an isolated punctuation sign — the pattern
matched nothing.

The replacement is literal: the previous version built a replacement text
containing \\1 while the pattern defined no group, which made `replace-match'
fail on the very first keyword."
  (goto-char (point-min))
  (let* ((alphabetic (string-match-p "\\`[[:alpha:]]" keyword))
         (pattern (if alphabetic
                      (concat "\\b" (regexp-quote keyword) "\\b")
                    (regexp-quote keyword))))
    (while (search-forward-regexp pattern nil t)
      (replace-match (if (eq newline-position 'after)
                         (concat keyword "\n")
                       (concat "\n" keyword))
                     t t))))

(defun sql-beautiful-region (region-start region-end)
  "Format the SQL query between REGION-START and REGION-END."

  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region region-start region-end)
      (sqlup-capitalize-keywords-in-region (point-min) (point-max))

      (dolist (keyword sql-beautiful-break-after)
        (sql-beautiful--break keyword 'after))
      (dolist (keyword sql-beautiful-break-before)
        (sql-beautiful--break keyword 'before))

      (indent-region (point-min) (point-max))))
  (message "Ah, much better!"))

(provide 'conf-sql)

;;; conf-sql.el ends here
