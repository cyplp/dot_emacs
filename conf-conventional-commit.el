;;; conf-conventional-commit.el --- conventional commits message coloring -*- lexical-binding: t -*-

;;; Commentary:

;; Syntax coloring of the Conventional Commits prefix in the commit message
;; buffers opened by magit:
;;
;;   type(scope)!: summary
;;
;; The `conventional-commit' package already installed only provides completion
;; of the type and of the scope; nothing visually distinguishes the prefix from
;; the summary, nor reports a message that does not follow the format. That is
;; what this module adds: the prefix is colored, and a summary line without a
;; valid prefix (no prefix at all, or a type outside the list) is shown in red
;; as a whole.
;;
;; The list of recognized types is not redefined here: it is read from
;; `conventional-commit-type-list', so that completion and coloring cannot
;; diverge.
;;
;; Two colorings coexist, chosen at setup time from what the buffer offers:
;;
;; - tree-sitter, when the message is parsed by `git-commit-ts-mode' (see
;;   conf-git.el): the grammar hands over the subject and its prefix as nodes,
;;   and a subject without a `prefix' node is by construction one that does not
;;   follow the format. The grammar accepts any word as a type, so the check
;;   against the list stays here. Known limit of the grammar: comments
;;   separated from the subject by a blank line (a squash message) push the
;;   subject into the body, which is then not judged.
;;
;; - regular expressions, as a fallback when the grammar is missing and the
;;   message is a plain `text-mode' buffer colored by git-commit.
;;
;; Both paths apply the same faces, so the message looks the same either way.
;;
;; The patterns are installed with the OVERRIDE flag: git-commit already colors
;; the whole summary line with the `git-commit-summary' face, and without that
;; flag our faces would simply be ignored on that part.

;;; Code:

(require 'conventional-commit)
(require 'treesit)

(defun my-conventional-commit-known-type-p (type)
  "Non-nil when TYPE is one of `conventional-commit-type-list'."
  (member type conventional-commit-type-list))

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

(defface my-conventional-commit-invalid-summary
  '((t :inherit error))
  "Face of the whole summary line when it has no valid prefix.
Applies to a summary without any prefix as well as to a type absent from
`conventional-commit-type-list': the tools that read the history reject both."
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

;;; Regular expression coloring

(defun my-conventional-commit-preamble-regexp ()
  "Pattern of what git may leave before the summary line.
The summary line is not always the first one of the buffer: git sometimes
leaves blank lines or comments there. This is the same skip as in
`git-commit-summary-regexp', so as to color only the real summary and never a
body line. The pattern is built at call time and not frozen in a constant: the
comment character comes from `core.commentchar' and is only known in the
buffer, once git-commit is set up."
  (format "\\`\\(?:^\\(?:\\s-*\\|%s.*\\)\n\\)*" (regexp-quote comment-start)))

(defun my-conventional-commit-header-regexp ()
  "Pattern of the conventional commit prefix on the summary line."
  (concat
   (my-conventional-commit-preamble-regexp)
   "\\([[:alnum:]]+\\)"                 ; type
   "\\(?:(\\([^)\n]+\\))\\)?"           ; optional scope
   "\\(!\\)?"                           ; optional breaking marker
   ":"))

(defun my-conventional-commit-summary-regexp ()
  "Pattern of a non-empty summary line, captured in group 1.
The first character excludes the comment character and whitespace: without
that, on a buffer holding only comments, the preamble would backtrack and hand
its last comment line over as the summary."
  (concat
   (my-conventional-commit-preamble-regexp)
   (format "\\([^[:space:]%c].*\\)$" (string-to-char comment-start))))

(defun my-conventional-commit-valid-prefix-p ()
  "Non-nil when the summary line starting at point carries a valid prefix.
Valid means the Conventional Commits shape with a type listed in
`conventional-commit-type-list'. The match data is left untouched."
  (save-match-data
    (and (looking-at (my-conventional-commit-header-regexp))
         (my-conventional-commit-known-type-p (match-string 1)))))

(defun my-conventional-commit-match-invalid-summary (limit)
  "Font-lock matcher of a summary line whose prefix is invalid.
Search from point up to LIMIT, as font-lock expects; both patterns are anchored
at the beginning of the buffer, so nothing matches when font-lock refontifies
a region that starts further down."
  (and (not (my-conventional-commit-valid-prefix-p))
       (re-search-forward (my-conventional-commit-summary-regexp) limit t)))

(defun my-conventional-commit-type-face ()
  "Face to apply to the type that has just been recognized.
Called by font-lock with the match data of the header pattern still in place:
the type is therefore read from group 1."
  (if (my-conventional-commit-known-type-p (match-string 1))
      'my-conventional-commit-type
    'my-conventional-commit-unknown-type))

(defun my-conventional-commit-font-lock-keywords ()
  "font-lock patterns of the conventional commits format for the current buffer."
  (list
   ;; Listed first: when the type is unknown, the whole line turns red and the
   ;; type face is then laid over it, which still points at the culprit.
   '(my-conventional-commit-match-invalid-summary
     (1 'my-conventional-commit-invalid-summary t))

   (list (my-conventional-commit-header-regexp)
         '(1 (my-conventional-commit-type-face) t)
         '(2 'my-conventional-commit-scope t t)
         '(3 'my-conventional-commit-breaking t t))

   (list my-conventional-commit-breaking-footer-regexp
         '(1 'my-conventional-commit-breaking t))))

(defun my-conventional-commit-setup-regexp-font-lock ()
  "Add the regexp coloring to the current message buffer.
The patterns are appended at the end of the list: git-commit's run first and
our prefix is laid over the summary."
  (font-lock-add-keywords nil (my-conventional-commit-font-lock-keywords) t))

;;; Tree-sitter coloring

(defconst my-conventional-commit-treesit-feature 'conventional-commit
  "Name of our font-lock feature in the tree-sitter settings.
A rule whose feature is absent from `treesit-font-lock-feature-list' is never
applied: the feature is added to the first level at setup time.")

(defun my-conventional-commit-treesit-node-child-of-type (node type)
  "First child of NODE whose node type is TYPE, or nil."
  (car (treesit-filter-child
        node
        (lambda (child) (equal (treesit-node-type child) type)))))

(defun my-conventional-commit-treesit-subject-type (subject-node)
  "Text of the conventional type of SUBJECT-NODE, or nil without a prefix."
  (when-let* ((prefix-node (my-conventional-commit-treesit-node-child-of-type
                            subject-node "prefix"))
              (type-node (my-conventional-commit-treesit-node-child-of-type
                          prefix-node "type")))
    (treesit-node-text type-node t)))

(defun my-conventional-commit-treesit-fontify-subject (node override start end &rest _)
  "Color the whole subject NODE in red when it has no valid prefix.
No prefix, or a type outside the list, both count as invalid. OVERRIDE, START
and END are those handed over by font-lock."
  (let ((type (my-conventional-commit-treesit-subject-type node)))
    (unless (and type (my-conventional-commit-known-type-p type))
      (treesit-fontify-with-override
       (treesit-node-start node) (treesit-node-end node)
       'my-conventional-commit-invalid-summary override start end))))

(defun my-conventional-commit-treesit-fontify-type (node override start end &rest _)
  "Color the type NODE according to its presence in the list.
OVERRIDE, START and END are those handed over by font-lock."
  (treesit-fontify-with-override
   (treesit-node-start node) (treesit-node-end node)
   (if (my-conventional-commit-known-type-p (treesit-node-text node t))
       'my-conventional-commit-type
     'my-conventional-commit-unknown-type)
   override start end))

(defun my-conventional-commit-treesit-settings ()
  "Tree-sitter font-lock rules of the conventional commits format.
Built at call time: `treesit-font-lock-rules' compiles the queries, which
needs the grammar to be loaded. The subject rule comes first on purpose: the
prefix faces are then laid over the red, which still points at the culprit."
  (treesit-font-lock-rules
   :feature my-conventional-commit-treesit-feature
   :language 'gitcommit
   :override t
   '((subject) @my-conventional-commit-treesit-fontify-subject
     (prefix (type) @my-conventional-commit-treesit-fontify-type)
     (prefix (scope) @my-conventional-commit-scope)
     (prefix "!" @my-conventional-commit-breaking)
     (breaking_change (token) @my-conventional-commit-breaking))))

(defun my-conventional-commit-setup-treesit-font-lock ()
  "Add the tree-sitter coloring to the current message buffer.
Our rules are appended after those of `git-commit-ts-mode', so that they win
on the prefix and on an invalid subject."
  (setq-local treesit-font-lock-settings
              (append treesit-font-lock-settings
                      (my-conventional-commit-treesit-settings)))
  (setq-local treesit-font-lock-feature-list
              (cons (cons my-conventional-commit-treesit-feature
                          (car treesit-font-lock-feature-list))
                    (cdr treesit-font-lock-feature-list)))
  (treesit-font-lock-recompute-features))

;;; Setup

(defun my-conventional-commit-setup-font-lock ()
  "Add the conventional commits coloring to the current message buffer.
The tree-sitter rules apply as soon as a gitcommit parser lives in the
buffer, the regexps otherwise: a major mode without a working grammar
\(`git-commit-ts-mode' with the library missing\) has no parser and falls back
on the regexps like `text-mode' does."
  (if (treesit-parser-list nil 'gitcommit)
      (my-conventional-commit-setup-treesit-font-lock)
    (my-conventional-commit-setup-regexp-font-lock))
  (font-lock-flush))

;; `git-commit-setup' binds `git-commit-mode-hook' to nil while it enables the
;; minor mode: a setting hooked there is never run on a commit started by
;; magit. `git-commit-setup-hook' is the intended entry point, and it runs after
;; `git-commit-setup-font-lock': git-commit's pattern list is therefore already
;; in place when we add ours to it.
(add-hook 'git-commit-setup-hook #'my-conventional-commit-setup-font-lock)

(provide 'conf-conventional-commit)

;;; conf-conventional-commit.el ends here
