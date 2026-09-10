;;; conf-lsp.el --- Language servers and diagnostics -*- lexical-binding: t -*-

;;; Commentary:

;; A single LSP client: eglot, bundled with Emacs since version 29.  It
;; replaces lsp-mode and lsp-ui, which duplicated it language by language —
;; python and rust on one side, go on the other — with two sets of settings,
;; two completion frontends and two diagnostic systems to maintain in
;; parallel.
;;
;; A single diagnostic system as well: flymake, also native and already fed by
;; eglot.  flycheck and its six plugins ran extra subprocesses to produce, in
;; the modes driven by a language server, exactly the same errors.
;;
;; The per-language modules only call `eglot-ensure'; everything common lives
;; here.

;;; Code:

(require 'eglot)

;; The events buffer logs every JSON message exchanged with the server. On an
;; active project that is several megabytes per session, formatted on each
;; insertion. Useless outside protocol debugging.
(setq eglot-events-buffer-config '(:size 0 :format full))

;; Caps how long a freeze lasts when a server does not answer (default: 30 s).
(setq eglot-request-timeout 10)

;; Does not block Emacs startup waiting for the handshake: past one second the
;; connection carries on in the background.
(setq eglot-sync-connect 1)

;; Stops the server with the last buffer of the project, instead of leaving one
;; gopls or rust-analyzer running per project visited in the session.
(setq eglot-autoshutdown t)

;; Lets `xref' follow a definition outside the current project, typically into
;; the standard library or the dependencies.
(setq eglot-extend-to-xref t)

;; Settings passed to the servers. The plist form is the one eglot expects
;; since Emacs 29; the old alist form is still accepted but obsolete.
(setq-default eglot-workspace-configuration
              '(:gopls (:staticcheck t
                        :matcher "CaseSensitive"
                        :usePlaceholders t)
                :rust-analyzer (:check (:command "clippy")
                                :cargo (:buildScripts (:enable t))
                                :procMacro (:enable t))))

;; Note on Python: `eglot-server-programs' already tries, in order, pylsp,
;; basedpyright, pyright, jedi-language-server then "ruff server". None needs
;; to be declared here. Only ruff is installed on this machine, which gives
;; formatting and linting but neither completion nor types: installing
;; basedpyright or pylsp would be enough to get the rest.

;; --- Diagnostics ------------------------------------------------------------

(use-package flymake
  :hook (emacs-lisp-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)
              ("C-c ! p" . flymake-show-project-diagnostics))
  :custom
  ;; The fringe flag is enough; the wavy underline makes long, already colored
  ;; lines unreadable.
  (flymake-fringe-indicator-position 'left-fringe)
  (flymake-no-changes-timeout 0.7))

;; shellcheck is the only useful flymake backend for shell scripts. Without the
;; binary, enabling flymake would only produce a failed-backend warning every
;; time a file is opened.
(when (executable-find "shellcheck")
  (add-hook 'sh-mode-hook #'flymake-mode)
  (add-hook 'bash-ts-mode-hook #'flymake-mode))

(provide 'conf-lsp)

;;; conf-lsp.el ends here
