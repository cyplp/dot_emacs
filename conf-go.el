;;; conf-go.el --- Go configuration -*- lexical-binding: t -*-

;;; Commentary:

;; `go-ts-mode', bundled with Emacs 30, replaces the MELPA package `go-mode'.
;; The latter is no longer maintained and its regexp-based analysis breaks on
;; the generics introduced in Go 1.18.
;;
;; go-mode also provided `gofmt-before-save'.  That function only acts when
;; `major-mode' is exactly `go-mode': kept as is, it would never have formatted
;; a single file again after the switch.  Formatting therefore goes through
;; `reformatter', already used for XML in this configuration.

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

;; Emacs (especially in GUI) does not inherit the shell PATH: eglot therefore
;; does not find gopls in ~/go/bin. We pull in the login shell PATH.
(use-package exec-path-from-shell
  :ensure t
  :config
  (when (or (memq window-system '(mac ns x pgtk))
            (daemonp))
    (exec-path-from-shell-initialize)))

;; Safety net: ~/go/bin in exec-path and PATH even without the shell.
(let ((go-binary-directory (expand-file-name "~/go/bin")))
  (add-to-list 'exec-path go-binary-directory)
  (setenv "PATH" (concat go-binary-directory path-separator (getenv "PATH"))))

;; goimports formats AND reorganizes imports in a single short subprocess,
;; where the LSP code action "source.organizeImports" waits for the gopls
;; answer, blocking Emacs on every save.
;;
;; The -srcdir option gives goimports the directory of the file: without it it
;; works on an anonymous stream and cannot resolve the imports of the current
;; module, which makes it remove imports that are in fact valid.
(reformatter-define go-format
  :program "goimports"
  :args (list "-srcdir" (or (buffer-file-name) default-directory)))

(defun my-go-setup ()
  "Settings common to Go buffers."
  (eglot-ensure)
  (go-format-on-save-mode 1)
  ;; Go mandates tabs; the display width remains a preference.
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 4))

(add-hook 'go-ts-mode-hook #'my-go-setup)

;; gopls also serves go.mod: completion of module versions and diagnostics on
;; the require / replace directives.
(add-hook 'go-mod-ts-mode-hook #'eglot-ensure)

(with-eval-after-load 'go-ts-mode
  (setq go-ts-mode-indent-offset 4))

;; The gopls settings (staticcheck, matcher) are in conf-lsp.el, with the rest
;; of the eglot configuration.

(provide 'conf-go)

;;; conf-go.el ends here
