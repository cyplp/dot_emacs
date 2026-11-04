;;; test-conventional-commit.el --- tests of the conventional commits coloring -*- lexical-binding: t -*-

;;; Commentary:

;; Run from the root of the repository:
;;
;;   emacs -Q --batch -l ert -l tests/test-conventional-commit.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; The tests fontify a message buffer the way magit sets it up, then read the
;; face at chosen positions. Every scenario runs on both colorings: the
;; regexps of a `text-mode' buffer and the tree-sitter rules of a
;; `git-commit-ts-mode' buffer. The tree-sitter tests skip themselves when the
;; gitcommit grammar is not installed.
;;
;; `git-commit', `conventional-commit' and `git-commit-ts-mode' come from
;; `elpa', which `emacs -Q' does not put in the `load-path': the directories
;; are added by hand below.

;;; Code:

(require 'ert)

(defconst my-conventional-commit-test-root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Root of the repository.")

(dolist (package-directory
         (directory-files (expand-file-name "elpa" my-conventional-commit-test-root)
                          t "\\`\\(magit\\|conventional-commit\\|git-commit-ts-mode\\|transient\\|with-editor\\|compat\\|llama\\|cond-let\\|dash\\|magit-section\\)-[0-9]"))
  (add-to-list 'load-path package-directory))

(require 'git-commit)
(require 'conventional-commit)
(require 'git-commit-ts-mode)

(load (expand-file-name "conf-conventional-commit.el" my-conventional-commit-test-root)
      nil t)

;;; Helpers

(defun my-conventional-commit-test--fontify (message coloring)
  "Return a fontified message buffer holding MESSAGE.
COLORING is `regexp' for a `text-mode' buffer colored by git-commit, or
`treesit' for a `git-commit-ts-mode' buffer. The buffer is set up as magit does
it: the major mode and its own font-lock first, then our hook, so that the
order of the patterns is the real one."
  (let ((buffer (generate-new-buffer " *conventional-commit-test*")))
    (with-current-buffer buffer
      (if (eq coloring 'treesit)
          (git-commit-ts-mode)
        (text-mode)
        (setq-local font-lock-multiline t)
        (font-lock-add-keywords nil git-commit-font-lock-keywords))
      (insert message)
      ;; `git-commit-setup-font-lock' reads `core.commentchar' through magit,
      ;; which needs a repository: `comment-start' is fixed here instead.
      (setq-local comment-start "#")
      (my-conventional-commit-setup-font-lock)
      (font-lock-ensure))
    buffer))

(defun my-conventional-commit-test--faces (message text &optional coloring)
  "Faces found on the first occurrence of TEXT in the fontified MESSAGE.
COLORING is passed to `my-conventional-commit-test--fontify' and defaults to
`regexp'. Return a list, whatever the shape font-lock stored the property
under."
  (with-current-buffer (my-conventional-commit-test--fontify message (or coloring 'regexp))
    (goto-char (point-min))
    (search-forward text)
    (let ((face (get-text-property (match-beginning 0) 'face)))
      (prog1 (if (listp face) face (list face))
        (kill-buffer)))))

;;; Valid messages keep the prefix coloring

(ert-deftest my-conventional-commit-test-known-type-is-not-red ()
  (should (equal (my-conventional-commit-test--faces "feat(auth): add login\n" "add login")
                 '(git-commit-summary)))
  (should (equal (my-conventional-commit-test--faces "feat(auth): add login\n" "feat")
                 '(my-conventional-commit-type)))
  (should (equal (my-conventional-commit-test--faces "feat(auth): add login\n" "auth")
                 '(my-conventional-commit-scope))))

(ert-deftest my-conventional-commit-test-breaking-marker-keeps-its-face ()
  (should (equal (my-conventional-commit-test--faces "fix!: drop v1\n" "!")
                 '(my-conventional-commit-breaking))))

;;; Invalid messages turn the summary red

(ert-deftest my-conventional-commit-test-summary-without-prefix-is-red ()
  (should (equal (my-conventional-commit-test--faces "random title\n" "random title")
                 '(my-conventional-commit-invalid-summary))))

(ert-deftest my-conventional-commit-test-unknown-type-is-red-with-type-marked ()
  (should (equal (my-conventional-commit-test--faces "foo: add login\n" "add login")
                 '(my-conventional-commit-invalid-summary)))
  (should (equal (my-conventional-commit-test--faces "foo: add login\n" "foo")
                 '(my-conventional-commit-unknown-type))))

(ert-deftest my-conventional-commit-test-summary-after-comments-is-red ()
  "Git may leave comments before the summary; the real summary is still found."
  (should (equal (my-conventional-commit-test--faces "# please edit\n\nrandom title\n"
                                                     "random title")
                 '(my-conventional-commit-invalid-summary))))

(ert-deftest my-conventional-commit-test-body-line-is-never-red ()
  "Only the summary is judged: a body line without a prefix is normal text."
  (should-not (member 'my-conventional-commit-invalid-summary
                      (my-conventional-commit-test--faces "feat: add login\n\nno prefix here\n"
                                                          "no prefix here"))))

(ert-deftest my-conventional-commit-test-comment-only-buffer-is-not-red ()
  "An empty message shows only git's comments; none of them is a summary."
  (should-not (member 'my-conventional-commit-invalid-summary
                      (my-conventional-commit-test--faces "\n# please edit\n# lines\n"
                                                          "# lines"))))

;;; Tree-sitter coloring

(defun my-conventional-commit-test--treesit-faces (message text)
  "Faces on TEXT in MESSAGE colored by the tree-sitter rules."
  (my-conventional-commit-test--faces message text 'treesit))

(defmacro my-conventional-commit-test--treesit-deftest (name &rest body)
  "Define the ERT test NAME running BODY on the tree-sitter coloring.
`skip-unless' is only meaningful inside a test body: the macro is what lets
every tree-sitter test skip itself when the gitcommit grammar is not
installed, without repeating the check."
  (declare (indent 1))
  `(ert-deftest ,name ()
     (skip-unless (treesit-ready-p 'gitcommit t))
     ,@body))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-known-type-is-not-red
  (should (equal (my-conventional-commit-test--treesit-faces "feat(auth): add login\n" "add login")
                 '(git-commit-ts-title-face)))
  (should (equal (my-conventional-commit-test--treesit-faces "feat(auth): add login\n" "feat")
                 '(my-conventional-commit-type)))
  (should (equal (my-conventional-commit-test--treesit-faces "feat(auth): add login\n" "auth")
                 '(my-conventional-commit-scope))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-breaking-marker-keeps-its-face
  (should (equal (my-conventional-commit-test--treesit-faces "fix!: drop v1\n" "!")
                 '(my-conventional-commit-breaking)))
  (should (equal (my-conventional-commit-test--treesit-faces
                  "fix: drop v1\n\nBREAKING CHANGE: v1 is gone\n" "BREAKING CHANGE")
                 '(my-conventional-commit-breaking))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-summary-without-prefix-is-red
  (should (equal (my-conventional-commit-test--treesit-faces "random title\n" "random title")
                 '(my-conventional-commit-invalid-summary))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-unknown-type-is-red-with-type-marked
  (should (equal (my-conventional-commit-test--treesit-faces "foo: add login\n" "add login")
                 '(my-conventional-commit-invalid-summary)))
  (should (equal (my-conventional-commit-test--treesit-faces "foo: add login\n" "foo")
                 '(my-conventional-commit-unknown-type))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-summary-after-comments-is-red
  "The grammar only accepts comments glued to the subject: with a blank line in
between (the shape of a squash message) the subject is parsed as body text and
is not judged. That limitation is upstream and is not covered here."
  (should (equal (my-conventional-commit-test--treesit-faces "# please edit\nrandom title\n"
                                                             "random title")
                 '(my-conventional-commit-invalid-summary))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-body-line-is-never-red
  (should-not (member 'my-conventional-commit-invalid-summary
                      (my-conventional-commit-test--treesit-faces
                       "feat: add login\n\nno prefix here\n" "no prefix here"))))

(my-conventional-commit-test--treesit-deftest my-conventional-commit-test-treesit-comment-only-buffer-is-not-red
  (should-not (member 'my-conventional-commit-invalid-summary
                      (my-conventional-commit-test--treesit-faces "\n# please edit\n# lines\n"
                                                                  "# lines"))))

(provide 'test-conventional-commit)

;;; test-conventional-commit.el ends here
