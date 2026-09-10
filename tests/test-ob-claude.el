;;; test-ob-claude.el --- claude org-babel block tests -*- lexical-binding: t -*-

;;; Commentary:

;; Run from the root of the repository:
;;
;;   emacs -Q --batch -l ert -l tests/test-ob-claude.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; No test calls the real CLI: it costs time and money, and its answer is not
;; deterministic. A stub script takes its place and merely returns what it
;; received, which is enough to check what is under our responsibility: the
;; arguments built, the prompt passed, and where the answer lands.

;;; Code:

(require 'ert)
(require 'org)

(add-to-list 'load-path
             (expand-file-name
              ".."
              (file-name-directory (or load-file-name buffer-file-name))))

(require 'ob-claude)

;;; Helpers

(defvar my-ob-claude-test--stub nil
  "Path of the stub script that replaces the CLI during the tests.")

(defun my-ob-claude-test--write-stub (script)
  "Write SCRIPT into an executable file and return its path."
  (let ((path (make-temp-file "ob-claude-stub" nil ".sh")))
    (with-temp-file path
      (insert "#!/bin/sh\n" script))
    (set-file-modes path #o755)
    path))

(defmacro my-ob-claude-test--with-stub (script &rest body)
  "Execute BODY with the CLI replaced by a stub running SCRIPT."
  (declare (indent 1))
  `(let ((my-ob-claude-test--stub (my-ob-claude-test--write-stub ,script)))
     (unwind-protect
         (let ((org-babel-claude-command my-ob-claude-test--stub)
               (org-confirm-babel-evaluate nil))
           ,@body)
       (delete-file my-ob-claude-test--stub))))

(defun my-ob-claude-test--execute-block (block)
  "Evaluate the first src block of BLOCK and return the resulting org buffer."
  (let ((buffer (generate-new-buffer "*test-ob-claude*")))
    (with-current-buffer buffer
      (org-mode)
      (insert block)
      (goto-char (point-min))
      (search-forward "#+begin_src")
      (org-babel-execute-src-block))
    buffer))

(defun my-ob-claude-test--wait-for-result (buffer)
  "Wait until the provisional token of BUFFER is replaced by the answer."
  (let ((deadline (+ (float-time) 10)))
    (while (and (< (float-time) deadline)
                (with-current-buffer buffer
                  (save-excursion
                    (goto-char (point-min))
                    (search-forward "claude-running:" nil t))))
      (accept-process-output nil 0.05))))

;;; Argument construction

(ert-deftest my-ob-claude-test-arguments-keep-print ()
  "The non-interactive mode is always requested."
  (should (member "--print" (org-babel-claude--build-arguments nil))))

(ert-deftest my-ob-claude-test-arguments-map-headers ()
  "Every recognized header becomes an option followed by its value."
  (let ((arguments (org-babel-claude--build-arguments
                    '((:model . "sonnet")
                      (:effort . "high")
                      (:system . "Answer in English")))))
    (should (equal (member "--model" arguments)
                   '("--model" "sonnet" "--effort" "high"
                     "--append-system-prompt" "Answer in English")))))

(ert-deftest my-ob-claude-test-arguments-ignore-unknown-headers ()
  "A header outside the mapping does not reach the command line."
  (should-not (member "--results"
                      (org-babel-claude--build-arguments '((:results . "drawer"))))))

(ert-deftest my-ob-claude-test-session-none-is-not-a-session ()
  "The org default value for `:session' creates no conversation."
  (should-not (member "--session-id"
                      (org-babel-claude--build-arguments '((:session . "none"))))))

(ert-deftest my-ob-claude-test-session-is-created-then-resumed ()
  "A session is created on the first block, then resumed by the next ones."
  (let ((org-babel-claude--session-identifiers (make-hash-table :test #'equal))
        (org-babel-claude--started-sessions (make-hash-table :test #'equal))
        (params '((:session . "review"))))
    (let ((creation (org-babel-claude--build-arguments params)))
      (should (member "--session-id" creation))
      ;; Resuming only makes sense after a completed call: it is the process
      ;; output that marks the session as started.
      (puthash "review" t org-babel-claude--started-sessions)
      (let ((resumption (org-babel-claude--build-arguments params)))
        (should (member "--resume" resumption))
        (should-not (member "--session-id" resumption))
        (should (equal (cadr (member "--resume" resumption))
                       (cadr (member "--session-id" creation))))))))

;;; Block body

(ert-deftest my-ob-claude-test-expand-body-substitutes-variables ()
  "A block variable replaces its marker in the prompt."
  (should (equal (org-babel-expand-body:claude
                  "Translate {{word}} into French."
                  '((:var . (word . "hello"))))
                 "Translate hello into French.")))

(ert-deftest my-ob-claude-test-expand-body-leaves-plain-text ()
  "A prompt without a marker goes through the expansion intact."
  (should (equal (org-babel-expand-body:claude "Nothing to substitute" nil)
                 "Nothing to substitute")))

;;; Synchronous execution

(ert-deftest my-ob-claude-test-sync-sends-prompt-on-stdin ()
  "The prompt is passed on standard input, not on the command line."
  (my-ob-claude-test--with-stub "cat"
    (should (equal (org-babel-execute:claude "Hello" '((:async . "no")))
                   "Hello"))))

(ert-deftest my-ob-claude-test-sync-reports-failure ()
  "A non-zero exit code comes back with the error message of the CLI."
  (my-ob-claude-test--with-stub "echo 'quota exceeded' >&2; exit 3"
    (let ((failure (should-error (org-babel-execute:claude "Hello"
                                                           '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 3" (cadr failure)))
      (should (string-match-p "quota exceeded" (cadr failure))))))

(ert-deftest my-ob-claude-test-empty-block-is-rejected ()
  "An empty block fails before any call to the CLI."
  (should-error (org-babel-execute:claude "   \n" nil) :type 'user-error))

;;; Asynchronous execution

(ert-deftest my-ob-claude-test-async-inserts-answer-in-drawer ()
  "The answer replaces the provisional token in the results drawer."
  (my-ob-claude-test--with-stub "cat"
    (let ((buffer (my-ob-claude-test--execute-block
                   "#+begin_src claude\nWhat time is it?\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-claude-test--wait-for-result buffer)
            (with-current-buffer buffer
              ;; `?' is a metacharacter: the comparison is on the literal
              ;; string, not on a regular expression.
              (should (string-search ":results:\nWhat time is it?\n:end:"
                                     (buffer-string)))))
        (kill-buffer buffer)))))

(ert-deftest my-ob-claude-test-async-reports-failure-in-buffer ()
  "A failure of the CLI is written into the result rather than lost."
  (my-ob-claude-test--with-stub "echo 'unknown session' >&2; exit 1"
    (let ((buffer (my-ob-claude-test--execute-block
                   "#+begin_src claude\nResume the session\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-claude-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-match-p "unknown session" (buffer-string)))))
        (kill-buffer buffer)))))

(provide 'test-ob-claude)

;;; test-ob-claude.el ends here
