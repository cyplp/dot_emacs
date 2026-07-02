(use-package python-mode
  :ensure t)

(autoload 'python-mode "python-mode" "Python Mode." t)
(add-to-list 'auto-mode-alist '("\\.py\\'" . python-mode))
(add-to-list 'interpreter-mode-alist '("python" . python-mode))
(setq interpreter-mode-alist
      (cons '("python" . python-mode)
	    interpreter-mode-alist)
      python-mode-hook
      '(lambda () (progn
		    (set-variable 'py-indent-offset 4)
		    (set-variable 'py-smart-indentation nil)
		    (set-variable 'indent-tabs-mode nil)
		    (highlight-lines-matching-regexp ".\{101\}" )
;;		    (highlight-beyond-fill-column)
                    (define-key python-mode-map "\C-m" 'newline-and-indent)
		    ;; (pabbrev-mode)
		    ;; (abbrev-mode)
	 )
      )
)
(add-hook 'python-mode-hook
      (lambda ()
        (setq indent-tabs-mode t)
        (setq tab-width 4)
        (setq python-indent 4)))


(defun python-add-breakpoint ()
    "Add a break point."
    (interactive)
    (newline-and-indent)
    (insert "breakpoint()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*breakpoint()")
    (save-buffer))

 (define-key python-mode-map (kbd "C-c C-b") 'python-add-breakpoint)

(defun python-add-remote-breakpoint ()
    "Add a break point."
    (interactive)
    (newline-and-indent)
    (insert "import rpdb; rpdb.set_trace()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*import rpdb; rpdb.set_trace()")
    (save-buffer))

(define-key python-mode-map (kbd "C-c C-r") 'python-add-remote-breakpoint)

(defun python-add-nose-breakpoint ()
    "Add a break point."
    (interactive)
    (newline-and-indent)
    (insert "import nose; nose.tools.set_trace()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*import nose; nose.tools.set_trace()")
    (save-buffer))

(define-key python-mode-map (kbd "C-c C-n") 'python-add-nose-breakpoint)

(defun python-add-noqa ()
  "add # NOQA."
  (interactive)
  (move-end-of-line nil)
  (insert "  # NOQA")
  )

(define-key python-mode-map (kbd "<f10>") 'python-add-noqa)


(defun python-replace-quote ()
  (interactive)
  (move-beginning-of-line nil)
  (let ((end (copy-marker (line-end-position))))
    (while (re-search-forward "\"" end t)
      (replace-match "'" nil nil)))
  (move-end-of-line nil)
  )

(define-key python-mode-map (kbd "<f9>") 'python-replace-quote)

(defun python-add-header-file ()
  (interactive)
  (goto-line 0)
  (insert "# coding: utf-8")
  (newline-and-indent)
  (insert "\"\"\"Some comment.\"\"\"")
  (newline-and-indent)
  (newline-and-indent)
  )

(define-key python-mode-map (kbd "<f8>") 'python-add-header-file)

(defun python-add-nocover ()
  "add # NOQA"
  (interactive)
  (move-end-of-line nil)
  (insert "  # pragma: nocover")
  (save-buffer)
  )

(define-key python-mode-map (kbd "C-p") 'python-add-nocover)


(defun telnet-rpdb()
  "Launch telnet on the default port of rpdb."
  (interactive)
  (telnet "127.0.0.1" 4444))


(defun py-help-at-point nil)

(use-package sphinx-doc
  :ensure t)
(add-hook 'python-mode-hook (lambda ()
                                  (require 'sphinx-doc)
                                  (sphinx-doc-mode t)))
;; add elpy
;; (use-package elpy
;;   :ensure t
;;   :config (elpy-enable))

;; flycheck reste actif globalement : lsp-mode l'utilise comme frontend pour
;; afficher ses diagnostics. En Python c'est pylsp (flake8 + mypy, cf.
;; lsp-register-custom-settings plus bas) qui les fournit.
;; flycheck-pycheckers et la selection forcee de 'python-flake8 ont ete retires :
;; ils entraient en concurrence avec le checker 'lsp' sur les buffers Python.
(global-flycheck-mode 1)

(define-key python-mode-map (kbd "C-f") 'flycheck-next-error)

(use-package flycheck-cython
  :ensure t)
(add-hook 'cython-mode-hook 'flycheck-mode)

;; ac-python retire : back-end auto-complete, remplace par corfu + lsp.

;; pip stuff
(use-package pip-requirements
  :ensure t)

(use-package blacken
 :ensure t)

(add-hook 'python-mode-hook 'blacken-mode)

;; binding for sphinx
(use-package sphinx-mode
  :ensure t)

;; sphinx-doc : deja declare plus haut (avec son hook python-mode), doublon retire.


(use-package lsp-mode
  :ensure t
  :commands lsp
  :custom
  ;; what to use when checking on-save. "check" is default, I prefer clippy
  (lsp-rust-analyzer-cargo-watch-command "clippy")
  (lsp-eldoc-render-all t)
  (lsp-idle-delay 0.6)
  ;; enable / disable the hints as you prefer:
  (lsp-rust-analyzer-server-display-inlay-hints t)
  (lsp-rust-analyzer-display-lifetime-elision-hints-enable "skip_trivial")
  (lsp-rust-analyzer-display-chaining-hints t)
  (lsp-rust-analyzer-display-lifetime-elision-hints-use-parameter-names nil)
  (lsp-rust-analyzer-display-closure-return-type-hints t)
  (lsp-rust-analyzer-display-parameter-hints nil)
  (lsp-rust-analyzer-display-reborrow-hints nil)

  :config
  (lsp-register-custom-settings
   '(("pyls.plugins.pyls_mypy.enabled" t t)
     ("pyls.plugins.pyls_mypy.live_mode" nil t)
     ("pyls.plugins.pyls_black.enabled" t t)))
  :hook
  ((python-mode . lsp)
   (lsp-mode-hook . lsp-ui-mode)))

(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :custom
  (lsp-ui-peek-always-show t)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-doc-enable nil))


;; elpy retire volontairement : il entrait en conflit avec lsp-mode
;; (double completion / navigation / verification) sur python-mode.
;; lsp-mode + lsp-ui (ci-dessus) sont la stack retenue.
