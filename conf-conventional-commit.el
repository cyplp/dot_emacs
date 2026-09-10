;;; conf-conventional-commit.el --- conventional commits message coloring -*- lexical-binding: t -*-

;;; Commentary:

;; Syntax coloring of the Conventional Commits prefix in the commit message
;; buffers opened by magit:
;;
;;   type(scope)!: summary
;;
;; The `conventional-commit' package already installed only provides completion
;; of the type and of the scope; nothing visually distinguishes the prefix from
;; the summary, nor reports a type outside the list. That is what this module
;; adds.
;;
;; The list of recognized types is not redefined here: it is read from
;; `conventional-commit-type-list', so that completion and coloring cannot
;; diverge.
;;
;; The patterns are installed with the OVERRIDE flag: git-commit already colors
;; the whole summary line with the `git-commit-summary' face, and without that
;; flag our faces would simply be ignored on that part.

;;; Code:

(require 'conventional-commit)

(defface my-conventional-commit-type
  '((t :inherit font-lock-keyword-face))
  "Face of the type when it appears in `conventional-commit-type-list'."
  :group 'git-commit)

(defface my-conventional-commit-unknown-type
  '((t :inherit font-lock-warning-face))
  "Face of a type absent from `conventional-commit-type-list'.
A type outside the list is rejected by the tools that read the history
\(changelog generation, version computation\): reporting it while writing
avoids having to rewrite the message afterwards."
  :group 'git-commit)

(defface my-conventional-commit-scope
  '((t :inherit font-lock-function-name-face))
  "Face of the scope, in parentheses after the type."
  :group 'git-commit)

(defface my-conventional-commit-breaking
  '((t :inherit error :weight bold))
  "Face of the breaking-change marker.
Covers the \"!\" of the prefix and the \"BREAKING CHANGE:\" footer."
  :group 'git-commit)

(defconst my-conventional-commit-breaking-footer-regexp
  "^\\(BREAKING[ -]CHANGE\\)!?:"
  "Pattern of the footer that declares a breaking change.
Both spellings are allowed by the specification.")

(defun my-conventional-commit-header-regexp ()
  "Pattern of the conventional commit prefix on the summary line.
The pattern is built at call time and not frozen in a constant: the comment
character comes from `core.commentchar' and is only known in the buffer, once
git-commit is set up."
  (concat
   ;; The summary line is not always the first one of the buffer: git sometimes
   ;; leaves blank lines or comments there. We skip the same header as
   ;; `git-commit-summary-regexp', so as to color only the real summary and
   ;; never a body line that would contain a colon.
   (format "\\`\\(?:^\\(?:\\s-*\\|%s.*\\)\n\\)*" (regexp-quote comment-start))
   "\\([[:alnum:]]+\\)"                 ; type
   "\\(?:(\\([^)\n]+\\))\\)?"           ; optional scope
   "\\(!\\)?"                           ; optional breaking marker
   ":"))

(defun my-conventional-commit-type-face ()
  "Face to apply to the type that has just been recognized.
Called by font-lock with the match data of the header pattern still in place:
the type is therefore read from group 1."
  (if (member (match-string 1) conventional-commit-type-list)
      'my-conventional-commit-type
    'my-conventional-commit-unknown-type))

(defun my-conventional-commit-font-lock-keywords ()
  "font-lock patterns of the conventional commits format for the current buffer."
  (list
   (list (my-conventional-commit-header-regexp)
         '(1 (my-conventional-commit-type-face) t)
         '(2 'my-conventional-commit-scope t t)
         '(3 'my-conventional-commit-breaking t t))

   (list my-conventional-commit-breaking-footer-regexp
         '(1 'my-conventional-commit-breaking t))))

(defun my-conventional-commit-setup-font-lock ()
  "Add the conventional commits coloring to the current message buffer.
The patterns are appended at the end of the list: git-commit's run first and
our prefix is laid over the summary."
  (font-lock-add-keywords nil (my-conventional-commit-font-lock-keywords) t)
  (font-lock-flush))

;; `git-commit-setup' binds `git-commit-mode-hook' to nil while it enables the
;; minor mode: a setting hooked there is never run on a commit started by
;; magit. `git-commit-setup-hook' is the intended entry point, and it runs after
;; `git-commit-setup-font-lock': git-commit's pattern list is therefore already
;; in place when we add ours to it.
(add-hook 'git-commit-setup-hook #'my-conventional-commit-setup-font-lock)

(provide 'conf-conventional-commit)

;;; conf-conventional-commit.el ends here
