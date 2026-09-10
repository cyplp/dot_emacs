;;; conf-xml.el --- XML and nXML -*- lexical-binding: t -*-

;;; Commentary:

;; `auto-complete-nxml' was dropped: auto-complete is no longer maintained and
;; in-buffer completion now goes through corfu (conf-completion.el), which
;; consumes nxml's candidates directly through
;; `completion-at-point-functions'.
;;
;; Formatting was declared twice: once by `reformatter-define' here, once by
;; the MELPA package `xml-format', which is nothing but the same call. Only the
;; local definition remains.

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

(use-package nxml-mode
  :mode (("\\.xml\\'" . nxml-mode)
         ("\\.xsl\\'" . nxml-mode)
         ("\\.zcml\\'" . nxml-mode)
         ("\\.plist\\'" . nxml-mode)
         ("\\.pt\\'" . nxml-mode))
  :bind (:map nxml-mode-map
              ("C-c h" . hs-toggle-hiding)
              ;; Binding moved from the global keymap, where it made
              ;; C-<return> unusable in every other mode.
              ;; `nxml-complete' is obsolete since Emacs 26: completion goes
              ;; through `completion-at-point', hence through corfu, which gets
              ;; the same candidates from the RELAX NG schema.
              ("C-<return>" . completion-at-point))
  :custom
  (nxml-child-indent 2)
  (nxml-attribute-indent 2)
  ;; Closes the tag as soon as the closing angle bracket is typed.
  (nxml-slash-auto-complete-flag t))

;; HTML5 schemas for nXML validation.
(use-package html5-schema
  :ensure t)

;; Path-based navigation in a structured document (XML, JSON).
(use-package x-path-walker
  :ensure t
  :commands (helm-x-path-walker))

;; --- Folding ----------------------------------------------------------------

;; hideshow does not know XML syntax: we describe the delimiters to it.
;; See https://emacs.stackexchange.com/questions/2884/
(with-eval-after-load 'hideshow
  (add-to-list 'hs-special-modes-alist
               '(nxml-mode
                 "<!--\\|<[^/>]*[^/]>"
                 "-->\\|</[^/>]*[^/]>"
                 "<!--"
                 sgml-skip-tag-forward
                 nil)))

(add-hook 'nxml-mode-hook #'hs-minor-mode)

;; --- Formatting -------------------------------------------------------------

;; `:mode' is left at its default value: that is what makes the macro generate
;; `xml-format-on-save-mode'. Setting it to nil removed that mode, and the hook
;; below only survived thanks to the MELPA package `xml-format', which defined
;; the same symbol.
(reformatter-define xml-format
  :program "xmllint"
  :args '("--format" "-"))

(add-hook 'nxml-mode-hook #'xml-format-on-save-mode)

(provide 'conf-xml)

;;; conf-xml.el ends here
