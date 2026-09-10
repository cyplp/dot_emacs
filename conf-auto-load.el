;;; conf-auto-load.el --- File / major-mode associations -*- lexical-binding: t -*-

;;; Commentary:

;; Associations that belong to no language module.
;;
;; Patterns are anchored with "\\'" (end of string) and not with "$" (end of
;; line), and the dot is escaped.  Old patterns such as "\.pl$" were read by
;; Emacs as "any character, then pl": a file named "toto-xpl" or "script.tpl"
;; opened in cperl-mode.

;;; Code:

;; cperl-mode is more complete than perl-mode and replaces it everywhere.
;; `major-mode-remap-alist' is the form intended for this since Emacs 29;
;; the old `defalias' on `perl-mode' redefined the function itself, which
;; prevents any code explicitly calling `perl-mode' from getting it.
(add-to-list 'major-mode-remap-alist '(perl-mode . cperl-mode))

(add-to-list 'auto-mode-alist '("\\.pl\\'" . cperl-mode))
(add-to-list 'auto-mode-alist '("\\.pm\\'" . cperl-mode))

(add-to-list 'auto-mode-alist '("\\.sql\\'" . sql-mode))
(add-to-list 'auto-mode-alist '("\\.java\\'" . java-mode))
(add-to-list 'auto-mode-alist '("\\.rst\\'" . rst-mode))
(add-to-list 'auto-mode-alist '("\\.cfg\\'" . conf-mode))
(add-to-list 'auto-mode-alist '("\\.ini\\'" . conf-mode))

;; The global RET binding to `newline-and-indent' was removed:
;; `electric-indent-mode' is on by default since Emacs 24.4 and has the same
;; effect, without overriding the RET keys specific to the minibuffer, to
;; commit buffers or to modes that repurpose the key.

(provide 'conf-auto-load)

;;; conf-auto-load.el ends here
