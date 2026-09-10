;;; conf-mcp.el --- Model Context Protocol servers -*- lexical-binding: t -*-

;;; Commentary:

;; `mcp.el' speaks the MCP protocol from Emacs: it manages the life cycle of
;; the servers — stdio process or HTTP endpoint — and exposes their tools,
;; prompts and resources to the rest of Emacs.  `mcp-hub' is its dashboard:
;; server list, start, stop, tool inspection.
;;
;; Not to be confused with the MCP server of `conf-claude.el', which goes the
;; other way: that one exposes Emacs to the Claude CLI, this one consumes
;; third-party servers from Emacs.
;;
;; The address and the token of the HTTP server are private data: they live in
;; `secret.el', outside the git repository.  This module only wires them up,
;; and stays inert if they are missing — on a machine without `secret.el' the
;; configuration loads without error and no server is declared.
;;
;; `secret.el' must define:
;;
;;   (setq my-mcp-http-server-url   "http://host:port/mcp")
;;   (setq my-mcp-http-server-token "...")

;;; Code:

;; --- Private settings -------------------------------------------------------

;; Default values nil: `secret.el' is loaded at the end of `init.el', hence
;; after this module.  The `defvar' only declares the variable, the `setq' in
;; `secret.el' then feeds it.

(defvar my-mcp-http-server-url nil
  "Address of the HTTP MCP server, or nil if there is none.
Defined in `secret.el', outside the git repository.")

(defvar my-mcp-http-server-token nil
  "Authentication token of the HTTP MCP server.
Defined in `secret.el', outside the git repository.")

(defvar my-mcp-http-server-name "local"
  "Name under which the HTTP MCP server appears in `mcp-hub'.")

;; Declaration without a value: the variable belongs to `mcp-hub', we only tell
;; the compiler that it exists.
(defvar mcp-hub-servers)

;; --- Server declaration -----------------------------------------------------

(defun my-mcp-register-http-server ()
  "Declare the private HTTP MCP server in `mcp-hub-servers'.
Does nothing as long as `my-mcp-http-server-url' or
`my-mcp-http-server-token' is not filled in by `secret.el'.

The entry is set with `alist-get' rather than with a `setq' of the whole
list: the other servers possibly declared elsewhere survive, and a second
call updates the entry instead of duplicating it."

  (when (and my-mcp-http-server-url my-mcp-http-server-token)
    (setf (alist-get my-mcp-http-server-name mcp-hub-servers nil nil #'equal)
          (list :url my-mcp-http-server-url
                ;; The `:token' keyword of mcp.el is not usable here: it builds
                ;; an "Authorization: Bearer ..." header, whereas this server
                ;; expects the "Token" scheme of Django REST Framework.  We
                ;; therefore pass the complete header.
                :headers `(("Authorization"
                            . ,(concat "Token " my-mcp-http-server-token)))))))

;; --- Package ----------------------------------------------------------------

;; No automatic start: the server listens locally and is not always running, so
;; a connection on every Emacs startup would most often fail for nothing.
;; `mcp-hub' starts what is useful, on demand.
;;
;; `C-c m' is already taken by `org-menu' in org buffers (conf-org.el).
(use-package mcp
  :ensure t
  :bind ("C-c M-m" . mcp-hub)
  :commands (mcp-hub mcp-connect-server))

;; The declaration waits for `mcp-hub' to be loaded — hence for the first call
;; to `mcp-hub' — for two reasons: `mcp-hub-servers' does not exist before, and
;; `secret.el' is then certain to have been loaded.
(with-eval-after-load 'mcp-hub
  (my-mcp-register-http-server))

(provide 'conf-mcp)

;;; conf-mcp.el ends here
