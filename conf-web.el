;;; conf-web.el --- Developpement web -*- lexical-binding: t -*-

;;; Commentary:

;; `json-mode' et `typescript-mode' ont ete retires : Emacs 30 fournit
;; `json-ts-mode' et `typescript-ts-mode', branches dans conf-treesit.el.
;; `less-css-mode' aussi : il fait partie de css-mode depuis Emacs 26.

;;; Code:

;; web-mode reste utile la ou tree-sitter ne suffit pas : les gabarits qui
;; melangent plusieurs langages dans un meme fichier (Jinja, Twig, ERB, Vue).
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


;; Emacs n'associe que .js, .jsx et .jsm ; les modules ES (.mjs) et les
;; modules CommonJS explicites (.cjs) restaient sans mode majeur.
(add-to-list 'auto-mode-alist '("\\.[cm]js\\'" . js-ts-mode))

(provide 'conf-web)

;;; conf-web.el ends here
