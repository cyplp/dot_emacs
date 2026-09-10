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

(provide 'conf-web)

;;; conf-web.el ends here
