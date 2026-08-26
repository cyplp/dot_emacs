;;; conf-sql.el --- SQL -*- lexical-binding: t -*-

;;; Commentary:

;; Edition SQL, connexions aux bases et mise en forme des requetes.
;;
;; `db-pg' a ete retire : le paquet est sans maintenance depuis 2013 et
;; tirait deux dependances (`db', `pg') pour un client PostgreSQL que
;; `sql-postgres' couvre nativement.

;;; Code:

(use-package sql-indent
  :ensure t
  :hook (sql-mode . sqlind-minor-mode))

;; Passe les mots-cles SQL en majuscules au fil de la frappe.
(use-package sqlup-mode
  :ensure t
  :hook ((sql-mode . sqlup-mode)
         (sql-interactive-mode . sqlup-mode))
  :bind ("C-c u" . sqlup-capitalize-keywords-in-region))

;; Menu de selection d'une connexion enregistree.
(use-package helm-sql-connect
  :ensure t
  :commands helm-sql-connect
  :config
  ;; Contournement de https://github.com/eric-hansen/helm-sql-connect/issues/3 :
  ;; le paquet lit une variable dont il ne definit que l'homonyme.
  (defvar helm-sql-connection-pool helm-sql-connect-pool))

;; Les connexions elles-memes vivent dans dbconnections.el, hors depot ; son
;; chargement est fait par init.el avec les autres fichiers prives.

;; --- Mise en forme ----------------------------------------------------------

(defconst sql-beautiful-break-after '("," "JOIN" "AND")
  "Mots-cles apres lesquels la requete passe a la ligne.")

(defconst sql-beautiful-break-before '("FROM" "WHERE")
  "Mots-cles avant lesquels la requete passe a la ligne.")

(defun sql-beautiful--break (keyword newline-position)
  "Inserer un saut de ligne autour de chaque occurrence de KEYWORD.
NEWLINE-POSITION vaut `after' ou `before' selon le cote ou placer le saut.

La recherche est bornee par les limites de la region retrecie par
l'appelant.  Les mots-cles alphabetiques sont delimites par `\\b' pour ne pas
couper un identifiant qui les contient, comme la colonne \"BRAND\" pour AND.
La virgule, elle, ne peut pas l'etre : `\\b' marque une frontiere entre
caractere de mot et non-mot, et n'en trouve donc jamais autour d'un signe de
ponctuation isole — le motif ne correspondait a rien.

Le remplacement est litteral : la version precedente construisait un texte
de remplacement contenant \\1 alors que le motif ne definissait aucun
groupe, ce qui faisait echouer `replace-match' des le premier mot-cle."
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
  "Mettre en forme la requete SQL comprise entre REGION-START et REGION-END."
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
