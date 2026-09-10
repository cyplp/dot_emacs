;;; conf-rust.el --- Rust configuration -*- lexical-binding: t -*-

;;; Commentary:

;; `rust-ts-mode' (Emacs 30) + eglot + rust-analyzer.
;;
;; This stack replaces four overlapping packages: `rust-mode' and `rustic' each
;; provided a major mode for .rs, `racer' offered completion and documentation
;; — the project has been archived since 2021, its role taken over by
;; rust-analyzer — and `cargo' was redundant with `cargo-mode', both enabling a
;; `cargo-minor-mode' on the same hook.
;;
;; `flycheck-rust' goes away with flycheck: clippy diagnostics now arrive
;; through rust-analyzer, hence through flymake (see conf-lsp.el).

;;; Code:

(use-package reformatter
  :ensure t
  :demand t)

;; rustfmt reads stdin and writes stdout: formatting does not go through the
;; language server and therefore cannot freeze Emacs waiting for rust-analyzer.
(reformatter-define rust-format
  :program "rustfmt"
  :args '("--emit" "stdout" "--quiet"))

(defun my-rust-setup ()
  "Settings common to Rust buffers."

  (eglot-ensure)
  (rust-format-on-save-mode 1))

;; Inline type hints, rust-analyzer's main contribution on heavily inferred
;; code, are enabled by eglot itself as soon as the server declares the
;; capability. Turning them on from the major-mode hook failed: at that point
;; `eglot-ensure' has not yet established the connection, and the command
;; raised a "No current JSON-RPC connection" error every time a .rs file was
;; opened.

(add-hook 'rust-ts-mode-hook #'my-rust-setup)

;; Running cargo commands from the current buffer.
(use-package cargo-mode
  :ensure t
  :hook (rust-ts-mode . cargo-minor-mode)
  ;; The minor mode keymap is called `cargo-minor-mode-map'; the name
  ;; `cargo-mode-map' does not exist, and the binding failed with a
  ;; "void-variable" when the mode was enabled.
  :bind (:map cargo-minor-mode-map
              ("C-c b" . cargo-mode-build)
              ("C-c t" . cargo-mode-test)))

;; The rust-analyzer settings (clippy, build scripts, procedural macros) are
;; in conf-lsp.el.

(provide 'conf-rust)

;;; conf-rust.el ends here
