;;; conf-claude.el --- Claude Code assistant -*- lexical-binding: t -*-

;;; Commentary:

;; Integration of the `claude' CLI into Emacs through claude-code-ide.el.
;;
;; The package does more than open a terminal: it starts an MCP server the CLI
;; connects to, which gives Claude the state of Emacs — current buffer,
;; selected region, flymake diagnostics, xref results — and routes proposed
;; edits through `ediff' instead of a patch printed in the terminal.
;;
;; The package is absent from MELPA: it is installed by `:vc', part of
;; use-package since Emacs 30.

;;; Code:

;; --- Terminal ---------------------------------------------------------------

;; The CLI is a full-screen application: it needs a real terminal emulator,
;; `shell' or `comint' are not enough. `eat' is written in pure Emacs Lisp,
;; where `vterm' — the package's default backend — requires a native build
;; (cmake, libtool) missing on this machine.
(use-package eat
  :ensure t
  :commands (eat eat-mode))

;; --- Claude Code ------------------------------------------------------------

;; Safety net: the CLI installs into ~/.local/bin, which the PATH of an Emacs
;; started from a graphical menu does not always contain. Same idiom as for
;; ~/go/bin in conf-go.el.
(let ((local-binary-directory (expand-file-name "~/.local/bin")))
  (add-to-list 'exec-path local-binary-directory)
  (setenv "PATH" (concat local-binary-directory path-separator (getenv "PATH"))))

;; The shortcuts start at F2 and not at F8: conf-org.el already uses F8, C-F8
;; and S-F8 for captures, and conf-python.el takes F8 over in python-mode-map.
;; F2 only serves as the two-column prefix by default, unused here.
(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind (("<f2>" . claude-code-ide-menu)
         ;; Shows or hides the session window without stopping it.
         ("<S-f2>" . claude-code-ide-toggle)
         ;; Passes Claude a reference to the region or the current file.
         ("<C-f2>" . claude-code-ide-insert-at-mentioned))
  :custom
  (claude-code-ide-terminal-backend 'eat)
  ;; The backend recommended upstream, `ghostel', is not installed here: the
  ;; reminder shown once per Emacs session would bring nothing.
  (claude-code-ide-show-backend-recommendation nil)
  :config
  ;; Exposes the Emacs-side MCP tools to Claude: xref, imenu, project,
  ;; diagnostics. Without this call the MCP server is limited to selection
  ;; notifications and to the ediff diff.
  (claude-code-ide-emacs-tools-setup))

;; --- Org blocks -------------------------------------------------------------

;; `ob-claude' makes `claude' an org-babel language: the block body is a
;; prompt, `C-c C-c' sends it to the CLI and the answer becomes the result.
(with-eval-after-load 'org
  (require 'ob-claude)

  ;; The prompt and the answer are markdown: `org-edit-special' opens the block
  ;; in markdown-mode rather than in `fundamental-mode'.
  (add-to-list 'org-src-lang-modes '("claude" . markdown))

  ;; `<cl' then TAB inserts the block.
  (add-to-list 'org-structure-template-alist '("cl" . "src claude")))

(provide 'conf-claude)

;;; conf-claude.el ends here
