;;; conf-git.el --- Git integration -*- lexical-binding: t -*-

;;; Commentary:

;; magit and its satellites.  The performance settings are kept: magit's status
;; buffer is the most frequent point of contact with a repository, and its
;; automatic refresh is what costs the most.

;;; Code:

;; Change marks in the fringe.
(use-package git-gutter
  :ensure t
  :hook (prog-mode . git-gutter-mode)
  :custom
  ;; 0 disables the periodic refresh: the fringe updates on buffer events,
  ;; without a timer waking Emacs while idle.
  (git-gutter:update-interval 0))

(use-package git-gutter-fringe
  :ensure t
  :after git-gutter
  :config
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom))

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :custom
  ;; Do not rebuild the status buffer after each command: on a big repository
  ;; every refresh spawns a dozen git subprocesses. `g' refreshes on demand.
  (magit-refresh-status-buffer nil)
  ;; Set to t to profile magit refresh times.
  (magit-refresh-verbose nil))

;; Word-by-word colored diff in magit, through delta.
(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

(use-package forge
  :ensure t
  :after magit
  :config
  ;; These sections query the forge API every time the status buffer opens.
  ;; The removal must happen after forge is loaded: forge is what installs
  ;; them, so the `remove-hook' calls at file load time — as was the case until
  ;; now — ran before the addition and had no effect.
  (remove-hook 'magit-status-sections-hook 'forge-insert-pullreqs)
  (remove-hook 'magit-status-sections-hook 'forge-insert-issues))

;; Major modes for .gitconfig, .gitignore, .gitattributes.
(use-package git-modes
  :ensure t)

(use-package gist
  :ensure t
  :commands (gist-region gist-buffer gist-list))

;; Shows the commit responsible for the current line.
;; Replaces git-messenger, unmaintained since 2019 and redundant with it.
(use-package vc-msg
  :ensure t
  :bind ("C-x v p" . vc-msg-show))

;; Open the current line in the forge web interface.
(use-package browse-at-remote
  :ensure t
  :bind ("C-x v b" . browse-at-remote))

(use-package gitlab-ci-mode
  :ensure t
  :mode ("\\.gitlab-ci\\.ya?ml\\'" . gitlab-ci-mode))

;; `gitlab-ci-mode-flycheck' is dropped along with flycheck; validation goes
;; through `M-x gitlab-ci-lint', which queries the GitLab API directly.

;; Assistance for writing messages in the Conventional Commits format.
;; `:vc' replaces the quelpa call: quelpa queried the remote repository on
;; every Emacs startup, where package-vc only acts at install time.
;; Coloring of the format lives in `conf-conventional-commit'.
(use-package conventional-commit
  :vc (:url "https://github.com/akirak/conventional-commit.el" :rev :newest)
  ;; `git-commit-setup' binds `git-commit-mode-hook' to nil while it enables
  ;; the minor mode: completion hooked there was never installed on a commit
  ;; started by magit. `git-commit-setup-hook' is the entry point magit
  ;; provides for configuring a message buffer.
  :hook (git-commit-setup . conventional-commit-setup))

(provide 'conf-git)

;;; conf-git.el ends here
