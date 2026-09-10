;;; test-org-emphasis.el --- tests of org emphasis on a region -*- lexical-binding: t -*-

;;; Commentary:

;; Run from the root of the repository:
;;
;;   emacs -Q --batch -l ert -l tests/test-org-emphasis.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; The tests assert the content of the buffer, never its rendering: in batch
;; mode neither `org-appear-mode' nor `org-hide-emphasis-markers' comes into
;; play. The only formatting assertion goes through the org parser, which is
;; deterministic.

;;; Code:

(require 'ert)
(require 'org)

(load (expand-file-name
       "../conf-org-emphasis.el"
       (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(define-derived-mode my-org-emphasis-test-derived-mode org-mode "TestOrg"
  "Mode derived from org-mode, to check the inheritance of `org-mode-map'.")

;;; Helpers

(defun my-org-emphasis-test--goto (target)
  "Put point just after TARGET.
TARGET is a string to search for, or nil for the end of the buffer."
  (goto-char (point-min))
  (if target
      (search-forward target)
    (goto-char (point-max))))

(defun my-org-emphasis-test--type-on-selection (content selection marker &optional mode)
  "Select SELECTION in CONTENT then type MARKER, in MODE.
Return the text of the resulting buffer. MODE defaults to `org-mode'."
  (with-temp-buffer
    (funcall (or mode #'org-mode))
    (insert content)
    (let ((end (my-org-emphasis-test--goto selection)))
      (set-mark (- end (length selection)))
      (goto-char end))

    (let ((last-command-event marker)
          (transient-mark-mode t))
      (call-interactively #'my-org-emphasize-region-or-self-insert))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun my-org-emphasis-test--type-without-selection (content target marker &optional command)
  "Put point after TARGET in CONTENT then type MARKER.
COMMAND allows replaying the same keystroke with another command, so as to
compare our fallback with the org command it delegates to."
  (with-temp-buffer
    (org-mode)
    (insert content)
    (my-org-emphasis-test--goto target)
    (deactivate-mark)

    (let ((last-command-event marker))
      (call-interactively (or command #'my-org-emphasize-region-or-self-insert)))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun my-org-emphasis-test--bold-contents (content)
  "Return the list of the fragments org parses as bold in CONTENT."
  (with-temp-buffer
    (org-mode)
    (insert content)
    (org-element-map (org-element-parse-buffer) 'bold
      (lambda (bold)
        (buffer-substring-no-properties
         (org-element-property :contents-begin bold)
         (org-element-property :contents-end bold))))))

;;; Slice 1 — wrapping of the active region and fallback outside a region

(ert-deftest my-org-emphasis-wraps-selection-with-typed-marker ()
  "A simple selection is wrapped with the typed marker."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a long sentence without interest" "long sentence" ?*))
        (expected "a *long sentence* without interest"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-wraps-selection-with-every-marker ()
  "Each of the markers of `org-emphasis-alist' wraps with itself."
  (dolist (emphasis org-emphasis-alist)
    (let* ((marker (string-to-char (car emphasis)))
           (data (my-org-emphasis-test--type-on-selection
                  "a long sentence without interest" "long sentence" marker))
           (expected (format "a %clong sentence%c without interest" marker marker)))
      (should (equal data expected)))))

(ert-deftest my-org-emphasis-leaves-non-marker-character-unbound ()
  "The dash is not an org marker: it must trigger no wrapping."
  (should-not (member "-" (mapcar #'car org-emphasis-alist)))
  (with-temp-buffer
    (org-mode)
    (should-not (eq (key-binding "-") #'my-org-emphasize-region-or-self-insert))))

(ert-deftest my-org-emphasis-without-selection-matches-org-self-insert ()
  "Without a region, the command matches `org-self-insert-command' exactly.
That is what guarantees that org's behaviour in tables — field blanking,
realignment — is preserved: it is delegated, never reimplemented."
  (let* ((table "| a | b |\n| c | d |\n")
         (data (my-org-emphasis-test--type-without-selection table "| a" ?=))
         (expected (my-org-emphasis-test--type-without-selection
                    table "| a" ?= #'org-self-insert-command)))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-without-selection-inserts-the-character ()
  "Without a region, the marker is inserted at point as an ordinary character."
  (let ((data (my-org-emphasis-test--type-without-selection "a sentence" nil ?*))
        (expected "a sentence*"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-keeps-single-emphasis-on-emphasized-selection ()
  "An already wrapped selection, markers included, keeps a single emphasis."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a *long sentence* without interest" "*long sentence*" ?*))
        (expected "a *long sentence* without interest"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-replaces-emphasis-instead-of-nesting ()
  "Typing another marker replaces the emphasis instead of nesting it."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a *long sentence* without interest" "*long sentence*" ?/))
        (expected "a /long sentence/ without interest"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-applies-in-modes-derived-from-org ()
  "A mode derived from org-mode inherits the behaviour and the bindings."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a long sentence without interest" "long sentence" ?*
               #'my-org-emphasis-test-derived-mode))
        (expected "a *long sentence* without interest"))
    (should (equal data expected)))
  (with-temp-buffer
    (my-org-emphasis-test-derived-mode)
    (should (eq (key-binding "*") #'my-org-emphasize-region-or-self-insert))))

(ert-deftest my-org-emphasis-does-not-leak-outside-org ()
  "Outside an org document, the markers stay ordinary characters."
  (dolist (emphasis org-emphasis-alist)
    (with-temp-buffer
      (fundamental-mode)
      (should-not (eq (key-binding (car emphasis))
                      #'my-org-emphasize-region-or-self-insert)))))

;;; Slice 2 — trimming of the spaces at the edges of the selection

(ert-deftest my-org-emphasis-trims-trailing-whitespace ()
  "A trailing space in the selection stays outside the markers."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a long sentence without interest" "long sentence " ?*))
        (expected "a *long sentence* without interest"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-trims-leading-whitespace ()
  "A leading space in the selection stays outside the markers."
  (let ((data (my-org-emphasis-test--type-on-selection
               "a long sentence without interest" " long sentence" ?*))
        (expected "a *long sentence* without interest"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-trims-trailing-newline ()
  "A newline at the edge of the selection is preserved outside the markers."
  (let ((data (my-org-emphasis-test--type-on-selection
               "first line\nsecond line\n" "first line\n" ?=))
        (expected "=first line=\nsecond line\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-produces-emphasis-org-recognizes ()
  "The trimming is what makes org really parse the fragment as bold.
Without it, \"*long sentence *\" would stay plain text: the gesture would
fail silently, markers visible and no formatting at all."
  (let ((data (my-org-emphasis-test--bold-contents
               (my-org-emphasis-test--type-on-selection
                "a long sentence without interest" "long sentence " ?*)))
        (expected '("long sentence")))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-blank-selection ()
  "A wholly blank selection is not wrapped."
  (let ((data (my-org-emphasis-test--type-on-selection "a    sentence" "    " ?*))
        (expected "a    *sentence"))
    (should (equal data expected))))

;;; Slice 3 — inertness outside an org text context

(ert-deftest my-org-emphasis-ignores-selection-in-source-block ()
  "A selection inside a code block is not wrapped."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_src python\nvalue = compute()\n#+end_src\n"
               "compute()" ?=))
        (expected "#+begin_src python\nvalue = compute()=\n#+end_src\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-selection-in-example-block ()
  "A selection inside an example block is not wrapped."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_example\nexample text\n#+end_example\n"
               "text" ?~))
        (expected "#+begin_example\nexample text~\n#+end_example\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-selection-on-keyword-line ()
  "A selection on a keyword line is not wrapped."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+TITLE: a long sentence\n" "long sentence" ?/))
        (expected "#+TITLE: a long sentence/\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-still-applies-in-ordinary-paragraph ()
  "The context detection must not disable the feature everywhere.
Without this positive case, an over-broad predicate would pass all the other
tests of the slice while making the wrapping inoperative in a normal
document."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_src python\nvalue = 1\n#+end_src\n\na long sentence without interest\n"
               "long sentence" ?*))
        (expected "#+begin_src python\nvalue = 1\n#+end_src\n\na *long sentence* without interest\n"))
    (should (equal data expected))))

;;; test-org-emphasis.el ends here
