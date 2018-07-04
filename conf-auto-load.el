;; perl
(defalias 'perl-mode 'cperl-mode)
(global-set-key "\r" 'newline-and-indent)
(add-to-list 'auto-mode-alist '("\.pl$" . cperl-mode))

;; SQL
(add-to-list 'auto-mode-alist '("\.sql$" . sql-mode))

;; java
(add-to-list 'auto-mode-alist '("\.java$" . java-mode))

;;xml
(add-to-list 'auto-mode-alist '("\.xml$" . nxml-mode))
(add-to-list 'auto-mode-alist '("\.xsl$" . nxml-mode))
(add-to-list 'auto-mode-alist '("\.zcml$" . nxml-mode))
(add-to-list 'auto-mode-alist '("\.plist$" . nxml-mode))
(add-to-list 'auto-mode-alist '("\.pt$" . nxml-mode))
(set-variable 'nxml-child-indent 2)

;; rst
(add-to-list 'auto-mode-alist '("\.rst$" . rst-mode))

;; cfg
(add-to-list 'auto-mode-alist '("\.cfg$" . conf-mode))

;; ini
(add-to-list 'auto-mode-alist '("\.ini$" . conf-mode))
