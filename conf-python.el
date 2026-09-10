;;; conf-python.el --- Python configuration -*- lexical-binding: t -*-

;;; Commentary:

;; We use the python.el bundled with Emacs 30 rather than the MELPA package
;; `python-mode'.  The latter binds TAB to `py-indent-line', which cycles
;; through the candidate indentation levels instead of computing the right one:
;; in an org src block, the code jumped from one column to another on every
;; TAB.
;;
;; Everything hooks onto `python-base-mode', the common ancestor of
;; `python-mode' and `python-ts-mode'.  That is what keeps the switch to
;; tree-sitter decided in conf-treesit.el from silently disabling the shortcuts
;; and the minor modes declared here.

;;; Code:

(require 'python)

;; eglot is loaded by conf-lsp.el, which comes before this module in
;; `my-configuration-modules'.

(add-hook 'python-base-mode-hook
          (lambda ()
            ;; buffer-local: these are global options by default
            (setq-local python-indent-offset 4)
            (setq-local indent-tabs-mode nil)
            (setq-local tab-width 4)))

;; --- Language server --------------------------------------------------------

(defconst my-python-language-servers
  '("basedpyright-langserver" "pyright-langserver" "pylsp" "jedi-language-server")
  "Accepted Python language servers, from the most complete to the simplest.

The default eglot list also falls back to \"ruff server\". That is a trap
here: pyenv installs a `ruff' shim visible from `executable-find' while the
binary only exists in one specific interpreter. eglot would therefore start a
server that fails immediately, every time a file is opened.")

(defun my-python-available-language-server ()
  "First server of `my-python-language-servers' present on the machine."
  (seq-find #'executable-find my-python-language-servers))

(defun my-python-setup-eglot ()
  "Start eglot only if a Python server is installed.
Without this guard, every Python file opened on a machine without a server
produces a connection error."
  (when (my-python-available-language-server)
    (eglot-ensure)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               (cons '(python-mode python-ts-mode)
                     (lambda (&rest _)
                       (let ((server (my-python-available-language-server)))
                         (if (member server '("basedpyright-langserver" "pyright-langserver"))
                             (list server "--stdio")
                           (list server)))))))

(add-hook 'python-base-mode-hook #'my-python-setup-eglot)

;; --- Writing helpers --------------------------------------------------------

(defun python-add-breakpoint ()
  "Insert a `breakpoint()' on a new line and save."
  (interactive)
  (newline-and-indent)
  (insert "breakpoint()")
  (newline-and-indent)
  (highlight-lines-matching-regexp "^[ ]*breakpoint()")
  (save-buffer))

(defun python-add-remote-breakpoint ()
  "Insert an rpdb breakpoint, reachable over telnet."
  (interactive)
  (newline-and-indent)
  (insert "import rpdb; rpdb.set_trace()")
  (newline-and-indent)
  (highlight-lines-matching-regexp "^[ ]*import rpdb; rpdb.set_trace()")
  (save-buffer))

(defun python-add-noqa ()
  "Append a `# NOQA' marker at the end of the current line."
  (interactive)
  (move-end-of-line nil)
  (insert "  # NOQA"))

(defun python-add-nocover ()
  "Append a `# pragma: nocover' marker at the end of the current line."
  (interactive)
  (move-end-of-line nil)
  (insert "  # pragma: nocover")
  (save-buffer))

(defun python-replace-quote ()
  "Replace the double quotes with single ones on the current line."
  (interactive)
  (save-excursion
    (move-beginning-of-line nil)
    (let ((line-end (copy-marker (line-end-position))))
      (while (re-search-forward "\"" line-end t)
        (replace-match "'" nil nil)))))

(defun python-add-header-file ()
  "Insert the module header: encoding then docstring."
  (interactive)
  ;; `goto-line' is reserved for interactive use and triggers a warning at
  ;; compile time; in Lisp we move directly.
  (goto-char (point-min))
  (insert "# coding: utf-8\n")
  (insert "\"\"\"Some comment.\"\"\"\n\n"))

(defun telnet-rpdb ()
  "Open a telnet on the default rpdb port."
  (interactive)
  (telnet "127.0.0.1" 4444))

;; The shortcuts apply to `python-base-mode-map' so as to hold in both
;; `python-mode' and `python-ts-mode'.
;;
;; The old "C-p" (nocover) and "C-f" (next error) bindings are given up: they
;; overrode `previous-line' and `forward-char' in every Python buffer. Walking
;; the errors now goes through flymake's M-n / M-p (conf-lsp.el).
(defconst my-python-key-bindings
  '(("C-c C-b" . python-add-breakpoint)
    ("C-c C-r" . python-add-remote-breakpoint)
    ("<f7>"    . python-add-nocover)
    ("<f8>"    . python-add-header-file)
    ("<f9>"    . python-replace-quote)
    ("<f10>"   . python-add-noqa))
  "Homemade shortcuts of the Python buffers.")

;; The bindings are installed on the two child keymaps and not on
;; `python-base-mode-map'. python.el already reserves some of these keys in the
;; keymaps of `python-mode' and `python-ts-mode' — C-c C-b is
;; `python-shell-send-block' there — and a child keymap always shadows its
;; parent: declaring in the common keymap is therefore not enough to take the
;; key back.
(dolist (python-keymap (list python-mode-map python-ts-mode-map))
  (dolist (binding my-python-key-bindings)
    (define-key python-keymap (kbd (car binding)) (cdr binding))))

;; --- Tools ------------------------------------------------------------------

;; Generation of docstrings in the Sphinx format.
(use-package sphinx-doc
  :ensure t
  :hook (python-base-mode . sphinx-doc-mode))

;; Coloring and shortcuts for reStructuredText files.
(use-package sphinx-mode
  :ensure t
  :commands sphinx-mode)

(use-package pip-requirements
  :ensure t
  :mode ("requirements\\(?:-[^/]*\\)?\\.txt\\'" . pip-requirements-mode))

;; Note on formatting: `blacken' was dropped, black not being installed here.
;; `ruff format' would replace it advantageously, but its binary is only
;; reachable in the pyenv 3.11 environment — wiring it onto `before-save-hook'
;; would make every save elsewhere fail. To be wired back the day the tool is
;; available globally.

(provide 'conf-python)

;;; conf-python.el ends here
