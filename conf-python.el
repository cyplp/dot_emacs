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
    "Add a break point"
    (interactive)
    (newline-and-indent)
    (insert "import pdb; pdb.set_trace()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*import pdb; pdb.set_trace()")
    (save-buffer))

 (define-key python-mode-map (kbd "C-c C-b") 'python-add-breakpoint)

(defun python-add-remote-breakpoint ()
    "Add a break point"
    (interactive)
    (newline-and-indent)
    (insert "import rpdb; rpdb.set_trace()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*import rpdb; rpdb.set_trace()")
    (save-buffer))

(define-key python-mode-map (kbd "C-c C-r") 'python-add-remote-breakpoint)

(defun python-add-nose-breakpoint ()
    "Add a break point"
    (interactive)
    (newline-and-indent)
    (insert "import nose; nose.tools.set_trace()")
    (newline-and-indent)
    (highlight-lines-matching-regexp "^[ ]*import nose; nose.tools.set_trace()")
    (save-buffer))

(define-key python-mode-map (kbd "C-c C-n") 'python-add-nose-breakpoint)

(defun python-add-noqa ()
  "add # NOQA"
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

(use-package flycheck-pycheckers
  :ensure t)
(global-flycheck-mode 1)
(with-eval-after-load 'flycheck
  (add-hook 'flycheck-mode-hook #'flycheck-pycheckers-setup)
  )

(use-package flycheck-cython
  :ensure t)
(add-hook 'cython-mode-hook 'flycheck-mode)