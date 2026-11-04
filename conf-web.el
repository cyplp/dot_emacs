;;; conf-web.el --- Web development -*- lexical-binding: t -*-

;;; Commentary:

;; `json-mode' and `typescript-mode' were dropped: Emacs 30 provides
;; `json-ts-mode' and `typescript-ts-mode', wired up in conf-treesit.el.
;; `less-css-mode' too: it is part of css-mode since Emacs 26.

;;; Code:

;; web-mode stays useful where tree-sitter is not enough: templates that mix
;; several languages in a single file (Jinja, Twig, ERB, Vue).
(use-package web-mode
  :ensure t
  :mode (("\\.html?\\'" . web-mode)
         ("\\.vue\\'" . web-mode)
         ("\\.jinja2?\\'" . web-mode)
         ("\\.twig\\'" . web-mode)
         ("\\.j2\\'" . web-mode))
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-enable-auto-closing t))


;; Emacs only associates .js, .jsx and .jsm; ES modules (.mjs) and explicit
;; CommonJS modules (.cjs) were left without a major mode.
(add-to-list 'auto-mode-alist '("\\.[cm]js\\'" . js-ts-mode))


;; HTTP requests in plain text files, run through the hurl CLI. Successor of
;; restclient.el (archived): the same .hurl files also run in CI.
;; Absent from MELPA, hence `:vc'. The package autoload already maps .hurl
;; files to `hurl-mode'.
(use-package hurl-mode
  :vc (:url "https://github.com/JasZhe/hurl-mode" :rev :newest)
  :commands hurl-mode)

;; ob-hurl ships in the same repository but has no autoload: Babel only finds
;; `org-babel-execute:hurl' once the file is loaded.
(use-package ob-hurl
  :ensure nil
  :after org)

(provide 'conf-web)

;;; conf-web.el ends here
