;;; test-ob-antigravity.el --- antigravity org-babel block tests -*- lexical-binding: t -*-

;;; Commentary:

;; Run from the root of the repository:
;;
;;   emacs -Q --batch -l ert -l tests/test-ob-antigravity.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; No test calls the real CLI: it costs time and money, and its answer is not
;; deterministic. A stub script takes its place and replays the exact shape of
;; the output of `agy' — a JSON envelope — which is enough to check what is
;; under our responsibility: the arguments built, the prompt passed, the
;; conversation identifier kept, and where the answer lands.

;;; Code:

(require 'ert)
(require 'org)

(add-to-list 'load-path
             (expand-file-name
              ".."
              (file-name-directory (or load-file-name buffer-file-name))))

(require 'ob-antigravity)

;;; Helpers

(defconst my-ob-antigravity-test--echo-prompt-stub
  "last=''
for argument in \"$@\"; do last=\"$argument\"; done
printf '{\"conversation_id\":\"conv-1\",\"status\":\"SUCCESS\",\"response\":\"%s\"}' \"${last#--print=}\"
"
  "Stub returning the prompt received in the JSON envelope of the CLI.
The prompt is read from the last argument, the only place `agy' accepts it:
the test fails if the prompt stops being carried there.")

(defconst my-ob-antigravity-test--error-stub
  "printf '{\"conversation_id\":\"\",\"status\":\"ERROR\",\"response\":\"\",\"error\":\"quota exceeded\"}'
exit 1
"
  "Stub replaying a failure announced by the CLI: JSON on stdout, code 1.")

(defun my-ob-antigravity-test--write-stub (script)
  "Write SCRIPT into an executable file and return its path."
  (let ((path (make-temp-file "ob-antigravity-stub" nil ".sh")))
    (with-temp-file path
      (insert "#!/bin/sh\n" script))
    (set-file-modes path #o755)
    path))

(defmacro my-ob-antigravity-test--with-stub (script &rest body)
  "Execute BODY with the CLI replaced by a stub running SCRIPT."
  (declare (indent 1))
  `(let ((stub-path (my-ob-antigravity-test--write-stub ,script)))
     (unwind-protect
         (let ((org-babel-antigravity-command stub-path)
               (org-babel-antigravity--conversation-identifiers
                (make-hash-table :test #'equal))
               (org-confirm-babel-evaluate nil))
           ,@body)
       (delete-file stub-path))))

(defun my-ob-antigravity-test--execute-block (block)
  "Evaluate the first src block of BLOCK and return the resulting org buffer."
  (let ((buffer (generate-new-buffer "*test-ob-antigravity*")))
    (with-current-buffer buffer
      (org-mode)
      (insert block)
      (goto-char (point-min))
      (search-forward "#+begin_src")
      (org-babel-execute-src-block))
    buffer))

(defun my-ob-antigravity-test--wait-for-result (buffer)
  "Wait until the provisional token of BUFFER is replaced by the answer."
  (let ((deadline (+ (float-time) 10)))
    (while (and (< (float-time) deadline)
                (with-current-buffer buffer
                  (save-excursion
                    (goto-char (point-min))
                    (search-forward "antigravity-running:" nil t))))
      (accept-process-output nil 0.05))))

;;; Argument construction

(ert-deftest my-ob-antigravity-test-arguments-keep-json-output ()
  "The JSON output is always requested: only it carries the conversation."
  (let ((arguments (org-babel-antigravity--build-arguments nil)))
    (should (equal (member "--output-format" arguments)
                   '("--output-format" "json")))))

(ert-deftest my-ob-antigravity-test-arguments-map-headers ()
  "Every recognized header becomes an option followed by its value."
  (let ((arguments (org-babel-antigravity--build-arguments
                    '((:model . "gemini-3.1-pro-high")
                      (:effort . "high")
                      (:mode . "plan")))))
    (should (equal (member "--model" arguments)
                   '("--model" "gemini-3.1-pro-high" "--effort" "high"
                     "--mode" "plan")))))

(ert-deftest my-ob-antigravity-test-arguments-ignore-unknown-headers ()
  "A header outside the mapping does not reach the command line."
  (should-not (member "--results"
                      (org-babel-antigravity--build-arguments
                       '((:results . "drawer"))))))

(ert-deftest my-ob-antigravity-test-prompt-is-attached-to-its-option ()
  "The prompt is glued to `--print': detached, the CLI ignores it."
  (should (equal (org-babel-antigravity--prompt-argument "Hello")
                 "--print=Hello")))

;;; Sessions

(ert-deftest my-ob-antigravity-test-session-none-is-not-a-session ()
  "The org default value for `:session' resumes no conversation."
  (should-not (member "--conversation"
                      (org-babel-antigravity--build-arguments
                       '((:session . "none"))))))

(ert-deftest my-ob-antigravity-test-first-block-opens-the-conversation ()
  "An unknown session has no identifier to resume."
  (let ((org-babel-antigravity--conversation-identifiers
         (make-hash-table :test #'equal)))
    (should-not (member "--conversation"
                        (org-babel-antigravity--build-arguments
                         '((:session . "review")))))))

(ert-deftest my-ob-antigravity-test-session-is-resumed-after-a-reply ()
  "The identifier returned by the CLI is resumed by the next block."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (org-babel-execute:antigravity "Hello" '((:async . "no")
                                             (:session . "review")))
    (should (equal (member "--conversation"
                           (org-babel-antigravity--build-arguments
                            '((:session . "review"))))
                   '("--conversation" "conv-1")))))

(ert-deftest my-ob-antigravity-test-conversation-is-not-kept-without-session ()
  "Without `:session', a block opens no tracked conversation."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (org-babel-execute:antigravity "Hello" '((:async . "no")))
    (should (zerop (hash-table-count
                    org-babel-antigravity--conversation-identifiers)))))

(ert-deftest my-ob-antigravity-test-reset-session-forgets-the-conversation ()
  "A reset session starts again with no identifier to resume."
  (let ((org-babel-antigravity--conversation-identifiers
         (make-hash-table :test #'equal)))
    (puthash "review" "conv-1" org-babel-antigravity--conversation-identifiers)
    (org-babel-antigravity-reset-session "review")
    (should-not (org-babel-antigravity--session-arguments "review"))))

;;; Block body

(ert-deftest my-ob-antigravity-test-expand-body-substitutes-variables ()
  "A block variable replaces its marker in the prompt."
  (should (equal (org-babel-expand-body:antigravity
                  "Translate {{word}} into French."
                  '((:var . (word . "hello"))))
                 "Translate hello into French.")))

(ert-deftest my-ob-antigravity-test-expand-body-leaves-plain-text ()
  "A prompt without a marker goes through the expansion intact."
  (should (equal (org-babel-expand-body:antigravity "Nothing to substitute" nil)
                 "Nothing to substitute")))

;;; Synchronous execution

(ert-deftest my-ob-antigravity-test-sync-returns-the-response-field ()
  "The answer is extracted from the JSON envelope, never returned raw."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (should (equal (org-babel-execute:antigravity "Hello" '((:async . "no")))
                   "Hello"))))

(ert-deftest my-ob-antigravity-test-sync-reports-declared-failure ()
  "A failure announced by the CLI comes back with its own reason."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--error-stub
    (let ((failure (should-error (org-babel-execute:antigravity
                                  "Hello" '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 1" (cadr failure)))
      (should (string-match-p "quota exceeded" (cadr failure))))))

(ert-deftest my-ob-antigravity-test-sync-reports-crash-without-json ()
  "A CLI dead before its answer comes back through its error output."
  (my-ob-antigravity-test--with-stub "echo 'panic' >&2; exit 2"
    (let ((failure (should-error (org-babel-execute:antigravity
                                  "Hello" '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 2" (cadr failure)))
      (should (string-match-p "panic" (cadr failure))))))

(ert-deftest my-ob-antigravity-test-empty-block-is-rejected ()
  "An empty block fails before any call to the CLI."
  (should-error (org-babel-execute:antigravity "   \n" nil) :type 'user-error))

(ert-deftest my-ob-antigravity-test-oversized-prompt-is-rejected ()
  "A prompt too long for an argument is refused with a named reason.
Without this guard, the call would fail on an E2BIG that nothing ties back
to the prompt."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (let ((failure (should-error
                    (org-babel-execute:antigravity
                     (make-string (1+ org-babel-antigravity--maximum-prompt-bytes) ?x)
                     '((:async . "no")))
                    :type 'user-error)))
      (should (string-match-p "too long" (cadr failure))))))

;;; Asynchronous execution

(ert-deftest my-ob-antigravity-test-async-inserts-answer-in-drawer ()
  "The answer replaces the provisional token in the results drawer."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (let ((buffer (my-ob-antigravity-test--execute-block
                   "#+begin_src antigravity\nWhat time is it\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-antigravity-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-search ":results:\nWhat time is it\n:end:"
                                     (buffer-string)))))
        (kill-buffer buffer)))))

(ert-deftest my-ob-antigravity-test-async-reports-failure-in-buffer ()
  "A failure of the CLI is written into the result rather than lost."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--error-stub
    (let ((buffer (my-ob-antigravity-test--execute-block
                   "#+begin_src antigravity\nResume the session\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-antigravity-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-match-p "quota exceeded" (buffer-string)))))
        (kill-buffer buffer)))))

(provide 'test-ob-antigravity)

;;; test-ob-antigravity.el ends here
