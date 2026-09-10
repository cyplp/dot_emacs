;;; init.el --- Main configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Single entry point.  This file holds only what must exist before everything
;; else: package archives, Emacs engine settings, and the loading of the
;; `conf-*.el' modules.  Any configuration tied to a specific language or tool
;; lives in its own module.

;;; Code:

(require 'package)

;; HTTPS everywhere: the GNU archive was still declared in clear text.
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

;; Always load the .el when it is newer than the matching .elc.
(setq load-prefer-newer t)

(package-initialize)

;; use-package is bundled since Emacs 29: the manual bootstrap is no longer
;; needed.  `require' is still necessary so that the macros are available when
;; the modules are compiled.
(require 'use-package)

;; Native compilation warnings come back in a loop about third-party packages
;; we will not fix; they hide the real messages.
(setq native-comp-async-report-warnings-errors 'silent)

;; --- Performance / anti-freeze ---------------------------------------------

;; The garbage collector is neutralized during initialization, where we
;; allocate massively and briefly, then brought back to a liveable threshold.
;; Keeping it at `most-positive-fixnum' in normal operation would defer
;; collection until a pause of several seconds.
(setq gc-cons-threshold most-positive-fixnum)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024))))

;; The LSP servers (gopls, rust-analyzer) send large JSON packets. The default
;; of 4096 bytes forces Emacs to loop thousands of times per answer: this is
;; the number one cause of freezes with eglot.
(setq read-process-output-max (* 4 1024 1024))

;; Automatically switches to degraded mode on files with very long lines
;; (minified JSON, logs, SQL dumps), where font-lock becomes unusable.
(global-so-long-mode 1)

;; The bidirectional text rendering algorithm is expensive and of no use here:
;; we force the left-to-right direction.
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Keeps Emacs from flushing its font caches under memory pressure, which
;; causes redisplay pauses with glyph-heavy themes.
(setq inhibit-compacting-font-caches t)

;; --- Fichiers ---------------------------------------------------------------

(setq make-backup-files nil) ; no backup~ files
(setq auto-save-default nil) ; no #autosave# files
(setq create-lockfiles nil)  ; no .# files

;; Warns when opening files larger than 100 MB.
(setq large-file-warning-threshold 100000000)

(setq require-final-newline t)
(setq next-line-add-newlines nil)

;; Reloads a buffer whose file changed on disk, dired included.
(setq global-auto-revert-non-file-buffers t)
(global-auto-revert-mode 1)

;; --- Interface --------------------------------------------------------------

(load-theme 'modus-operandi t)

(setq inhibit-splash-screen t)
(setq ring-bell-function 'ignore)

;; `%d' does not exist among the `frame-title-format' specifiers: the title
;; showed the letter as is. We show the buffer and its path.
(setq frame-title-format '("%b" (:eval (if buffer-file-name " — %f" "")) " — Emacs"))

(menu-bar-mode 0)
(tool-bar-mode 0)

(setq column-number-mode t)
(setq line-number-mode t)

;; One-letter answers. Replaces the old `fset' on `yes-or-no-p', which
;; overrode the function for everyone, including the calls where a long
;; confirmation is wanted.
(setq use-short-answers t)

(prefer-coding-system 'utf-8)

;; Shows only the tail of over-long lines, the tabs and the trailing
;; whitespace. The actual cleanup is handled by
;; `global-whitespace-cleanup-mode' (conf-misc.el), which only touches buffers
;; that are already clean.
(setq whitespace-line-column 88
      whitespace-style '(tabs trailing lines-tail))

(show-paren-mode t)
(winner-mode t)
(delete-selection-mode 1)

;; Automatic pairs. Replaces `skeleton-pair', whose activation went through
;; global bindings on "(", "[", "{" and the quote character: they applied to
;; every buffer, including the minibuffer and the text modes where
;; auto-pairing is not desirable.
(electric-pair-mode 1)

;; Pixel scrolling, native since Emacs 29.
(pixel-scroll-precision-mode 1)

(setq tramp-default-method "ssh")
(setq calendar-week-start-day 1)

(setq select-enable-clipboard t)

;; Limits the size of the *Messages* buffer.
(setq-default message-log-max 1000)

;; --- Base packages ----------------------------------------------------------

(use-package try
  :ensure t
  :commands try)

;; quelpa: installation from a git repository for packages absent from MELPA.
;; Kept for the packages already built; the new ones go through `:vc', part of
;; use-package since Emacs 30.
(use-package quelpa
  :ensure t
  :defer t)

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(use-package ace-window
  :ensure t
  :bind ([remap other-window] . ace-window))

(use-package expand-region
  :ensure t
  :bind ("C-œ" . er/expand-region))

;; Used by some yasnippet snippets to convert case.
(use-package string-inflection
  :ensure t
  :commands (string-inflection-underscore
             string-inflection-camelcase
             string-inflection-kebab-case))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

(use-package aws-snippets
  :ensure t
  :after yasnippet)

(use-package xclip
  :ensure t
  :config
  (xclip-mode 1))

(use-package helm
  :ensure t
  :bind (("M-x" . helm-M-x)
         ("C-c C-c M-x" . execute-extended-command))
  :init
  (setq helm-M-x-fuzzy-match t
        helm-mode-fuzzy-match t
        helm-buffers-fuzzy-matching t
        helm-recentf-fuzzy-match t
        helm-locate-fuzzy-match t
        helm-semantic-fuzzy-match t
        helm-imenu-fuzzy-match t
        helm-completion-in-region-fuzzy-match t
        ;; helm keeps the minibuffer, corfu keeps in-buffer completion
        helm-mode-handle-completion-in-region nil
        helm-candidate-number-list 150
        helm-split-window-inside-p t
        helm-move-to-line-cycle-in-source t
        helm-echo-input-in-header-line t
        helm-autoresize-max-height 0
        helm-autoresize-min-height 20)
  :config
  (helm-mode 1))

;; --- Module loading ---------------------------------------------------------

;; The modules are loaded by `require' and no longer by `load-file': the
;; absolute path disappears from the calls, a module already loaded is not
;; loaded twice, and byte-compilation becomes possible.
(add-to-list 'load-path (expand-file-name "." user-emacs-directory))

;; Custom writes into its own file so as not to rewrite this one.
(setq custom-file (locate-user-emacs-file "custom.el"))

(when (file-exists-p custom-file)
  (load custom-file nil t))

(defconst my-configuration-modules
  '(conf-treesit
    conf-completion
    conf-lsp
    ;; org
    conf-org
    conf-org-emphasis
    ;; misc
    conf-misc
    conf-python
    conf-git
    conf-conventional-commit
    conf-shortcut
    conf-auto-load
    conf-jabber
    conf-xml
    conf-rust
    conf-go
    conf-sql
    conf-web
    conf-thinkpad
    conf-dired
    conf-elisp
    conf-yaml
    conf-devops
    conf-linear
    conf-claude
    conf-antigravity
    conf-mcp
    conf-mcp-explorer
    conf-latex
    conf-webserver)
  "Configuration modules to load, in order.
The order matters: `conf-treesit' sets the major modes and `conf-lsp' the
eglot settings that the per-language modules depend on.")

(defun my-load-configuration-module (module)
  "Load MODULE while isolating its errors.
Without this isolation, a single error in one module interrupts the whole
rest of the loading and leaves Emacs half configured, with no clue about the
culprit.

MODULE is a feature symbol (see `provide')."
  (condition-case failure
      (require module)
    (error
     (message "Module %s not loaded: %s" module (error-message-string failure)))))


(mapc #'my-load-configuration-module my-configuration-modules)

;; Files outside the git repository: secrets, database connections, leftovers
;; from the old .emacs. Loaded with `load' as they have no `provide'.
(dolist (private-file '("secret.el" "dbconnections.el" "old.el"))
  (let ((path (locate-user-emacs-file private-file)))
    (when (file-exists-p path)
      (load path nil t))))

(message "conf loaded")

;;; init.el ends here
