;;; ob-antigravity.el --- org-babel blocks executed by the agy CLI -*- lexical-binding: t -*-

;;; Commentary:

;; Lets you write a prompt in an org block and send it to the `agy' CLI
;; (Google Antigravity) with `C-c C-c':
;;
;;   #+begin_src antigravity :model gemini-3.1-pro-high
;;   Summarize the role of this repository.
;;   #+end_src
;;
;; The block body is the prompt, the answer becomes the result of the block.
;;
;; Same behaviour as `ob-claude', with two differences imposed by the CLI:
;;
;; - the prompt travels in the command line, as the value of `--print', and not
;;   on standard input: `agy --print' requires its value, and it only reads
;;   stdin with `--input-format stream-json', which would force us to follow an
;;   NDJSON stream for a single round trip;
;;
;; - the output is requested in JSON, the only form that carries the
;;   conversation identifier. `agy' assigns that identifier itself, where the
;;   Claude CLI accepts being given one: a session can therefore only be
;;   resumed once a first block has completed.
;;
;; The call is asynchronous by default: an answer takes tens of seconds and
;; Emacs is single-threaded, so a synchronous call would freeze the editor for
;; that whole time. The block first receives a token, replaced by the answer
;; when the process ends. `:async no' makes the call blocking, useful in batch
;; mode or for the tests.
;;
;; Headers recognized, in addition to org's own:
;;
;;   :model    model identifier, as listed by `agy models'
;;   :effort   reasoning level (low, medium, high)
;;   :agent    agent to use for the session
;;   :mode     execution mode (accept-edits, plan)
;;   :project  Antigravity project identifier or name
;;   :add-dir  extra directory added to the workspace
;;   :session  name of a conversation followed from one block to the next
;;   :async    yes (default) or no
;;   :dir      working directory of the CLI, handled by org itself

;;; Code:

(require 'ob)
(require 'org-id)
(require 'subr-x)

;; --- Settings ---------------------------------------------------------------

(defgroup org-babel-antigravity nil
  "Execution of org-babel blocks by the Antigravity CLI."
  :group 'org-babel)

(defcustom org-babel-antigravity-command "agy"
  "Name or path of the Antigravity CLI executable."
  :type 'string
  :group 'org-babel-antigravity)

(defcustom org-babel-antigravity-base-arguments '("--output-format" "json")
  "Arguments passed on every call, before those derived from the headers.
The JSON output is not a parsing convenience: it is the only one that carries
the conversation identifier and a usable error status."
  :type '(repeat string)
  :group 'org-babel-antigravity)

;; A block without an answer is a visible error; a block that modifies files
;; behind the author's back is not. The default result is therefore a drawer —
;; the answer is free text, often multiline and in markdown — and export
;; evaluates nothing.
(defvar org-babel-default-header-args:antigravity
  '((:results . "drawer replace")
    (:exports . "both")
    (:eval . "never-export"))
  "Default headers of the `antigravity' blocks.")

;; Linux caps each argument at 128 KiB (MAX_ARG_STRLEN). Beyond that, the call
;; fails with an E2BIG that nothing ties back to the prompt: the limit is
;; checked here so that the message names the cause.
(defconst org-babel-antigravity--maximum-prompt-bytes 130000
  "Maximum size of the prompt, in bytes, once carried by `--print'.")

;; --- Translation of the headers into arguments ------------------------------

(defconst org-babel-antigravity--argument-by-header
  '((:model . "--model")
    (:effort . "--effort")
    (:agent . "--agent")
    (:mode . "--mode")
    (:project . "--project")
    (:add-dir . "--add-dir"))
  "Mapping between block header and CLI option.
Every header present adds its option followed by its value.")

(defun org-babel-antigravity--header-value (header params)
  "Return the value of HEADER in PARAMS, as a string.
Return nil if the header is absent or empty. Org reads the header values with
`org-babel-read', which can yield a number or a symbol: the value is
reformatted before landing in a command line."
  (let ((value (cdr (assq header params))))
    (when value
      (let ((text (string-trim (format "%s" value))))
        (unless (string-empty-p text)
          text)))))

;; --- Sessions ---------------------------------------------------------------

(defvar org-babel-antigravity--conversation-identifiers (make-hash-table :test #'equal)
  "Conversation identifier returned by the CLI, for each session name.
As long as a name is absent from it, its session has no conversation yet: the
next block will open one, and it is the answer of the CLI that will deliver
the identifier to remember.")

(defun org-babel-antigravity--session-name (params)
  "Return the session name declared in PARAMS, or nil.
Org gives the value \"none\" when no session is requested."
  (let ((session (org-babel-antigravity--header-value :session params)))
    (unless (member session '(nil "none"))
      session)))

(defun org-babel-antigravity--session-arguments (session-name)
  "Return the arguments that resume the conversation of SESSION-NAME.
Return nil as long as no conversation has been opened for that name."
  (when-let* ((identifier (gethash session-name
                                   org-babel-antigravity--conversation-identifiers)))
    (list "--conversation" identifier)))

(defun org-babel-antigravity--remember-conversation (session-name response)
  "Associate with SESSION-NAME the conversation identifier carried by RESPONSE.
Without a session name, the conversation is deliberately forgotten: the next
block starts again from an empty context."
  (when session-name
    (let ((identifier (alist-get 'conversation_id response)))
      (when (and identifier (not (string-empty-p identifier)))
        (puthash session-name identifier
                 org-babel-antigravity--conversation-identifiers)))))

(defun org-babel-antigravity-reset-session (session-name)
  "Forget the conversation associated with SESSION-NAME.
The next block of that session starts again from an empty context."
  (interactive (list (completing-read
                      "Session antigravity : "
                      (hash-table-keys org-babel-antigravity--conversation-identifiers)
                      nil t)))
  (remhash session-name org-babel-antigravity--conversation-identifiers)
  (message "Session antigravity %s reinitialisee" session-name))

;; --- Command line -----------------------------------------------------------

(defun org-babel-antigravity--build-arguments (params)
  "Build the CLI argument list from PARAMS.
The prompt is not part of it: it is appended last, where the CLI requires it
to be."
  (let ((arguments (copy-sequence org-babel-antigravity-base-arguments)))
    (dolist (entry org-babel-antigravity--argument-by-header)
      (let ((value (org-babel-antigravity--header-value (car entry) params)))
        (when value
          (setq arguments (append arguments (list (cdr entry) value))))))

    (let ((session-name (org-babel-antigravity--session-name params)))
      (when session-name
        (setq arguments
              (append arguments
                      (org-babel-antigravity--session-arguments session-name)))))

    arguments))

(defun org-babel-antigravity--prompt-argument (prompt)
  "Return the argument that carries PROMPT.
The value is glued to the option: otherwise `agy' takes the next option as
the prompt and ignores the rest of the line."
  (format "--print=%s" prompt))

;; --- Reading the answer -----------------------------------------------------

(defun org-babel-antigravity--parse-response (output)
  "Parse OUTPUT, the standard output of the CLI, and return its alist.
Return nil when the output is not JSON: a CLI that dies before its answer
writes free text, which is better shown as is than hidden behind a parsing
error."
  (condition-case nil
      (json-parse-string output
                         :object-type 'alist
                         :null-object nil
                         :false-object nil)
    (error nil)))

(defun org-babel-antigravity--successful-p (exit-code response)
  "Tell whether a call exited with EXIT-CODE and RESPONSE succeeded.
The exit code is not enough: the CLI describes the failure in its `status'
field, and both must agree for an answer to be published."
  (and (equal exit-code 0)
       (or (null response)
           (equal (alist-get 'status response) "SUCCESS"))))

(defun org-babel-antigravity--response-text (response output)
  "Return the text of RESPONSE, or OUTPUT when the JSON is missing."
  (string-trim (or (and response (alist-get 'response response))
                   output)))

(defun org-babel-antigravity--failure-message (exit-code response error-output)
  "Compose the failure message of a call exited with EXIT-CODE.
The reason is looked up first in the `error' field of RESPONSE, where the CLI
writes it; ERROR-OUTPUT only serves when it dies before producing its JSON."
  (let ((reason (string-trim (or (and response (alist-get 'error response))
                                 error-output
                                 ""))))
    (format "agy a echoue (code %s)%s"
            exit-code
            (if (string-empty-p reason)
                ""
              (concat " : " reason)))))

(defun org-babel-antigravity--interpret-output (exit-code output error-output session-name)
  "Interpret the output of a call and return a plist.
The plist carries `:successful' and `:text'. On success, SESSION-NAME — when
non-nil — keeps the conversation identifier returned by the CLI, so that the
next block of the same session resumes it.

EXIT-CODE, OUTPUT and ERROR-OUTPUT are the exit code, the standard output and
the error output of the process."
  (let ((response (org-babel-antigravity--parse-response output)))
    (if (org-babel-antigravity--successful-p exit-code response)
        (progn
          (org-babel-antigravity--remember-conversation session-name response)
          (list :successful t
                :text (org-babel-antigravity--response-text response output)))
      (list :successful nil
            :text (org-babel-antigravity--failure-message
                   exit-code response error-output)))))

;; --- Block body -------------------------------------------------------------

(defun org-babel-expand-body:antigravity (body params)
  "Substitute the variables of PARAMS in BODY.
A variable declared with `:var name=value' replaces every occurrence of
`{{name}}'. The double brace is chosen because it does not appear in ordinary
text, where `$name' would blend into the content of the prompt."
  (let ((prompt body))
    (dolist (variable (org-babel--get-vars params))
      (setq prompt
            (replace-regexp-in-string
             (regexp-quote (format "{{%s}}" (car variable)))
             (format "%s" (cdr variable))
             prompt
             'fixedcase
             'literal)))
    prompt))

;; --- Execution --------------------------------------------------------------

(defun org-babel-antigravity--async-p (params)
  "Tell whether the block described by PARAMS must run in the background."
  (not (member (org-babel-antigravity--header-value :async params) '("no" "nil"))))

(defun org-babel-antigravity--check-command ()
  "Check that the CLI is reachable, or signal an explicit error."
  (unless (executable-find org-babel-antigravity-command)
    (user-error "Executable %s not found in `exec-path'"
                org-babel-antigravity-command)))

(defun org-babel-antigravity--check-prompt-length (prompt)
  "Reject PROMPT when it exceeds what an argument can carry."
  (when (> (string-bytes prompt) org-babel-antigravity--maximum-prompt-bytes)
    (user-error "Prompt too long for agy: %d bytes, maximum %d"
                (string-bytes prompt)
                org-babel-antigravity--maximum-prompt-bytes)))

(defun org-babel-antigravity--file-contents (path)
  "Return the content of the file PATH."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun org-babel-antigravity--execute-synchronously (arguments session-name)
  "Call the CLI with ARGUMENTS and return its answer.
SESSION-NAME, when non-nil, keeps the conversation identifier on success.
Blocks Emacs until the call ends."
  (let ((error-file (make-temp-file "ob-antigravity-error")))
    (unwind-protect
        (with-temp-buffer
          ;; Empty standard input: the CLI does not read the prompt on stdin,
          ;; and an open pipe would leave it waiting.
          (let* ((exit-code (apply #'call-process
                                   org-babel-antigravity-command
                                   nil (list t error-file) nil
                                   arguments))
                 (outcome (org-babel-antigravity--interpret-output
                           exit-code
                           (string-trim (buffer-string))
                           (string-trim (org-babel-antigravity--file-contents error-file))
                           session-name)))
            (if (plist-get outcome :successful)
                (plist-get outcome :text)
              (user-error "%s" (plist-get outcome :text)))))
      (delete-file error-file))))

(defun org-babel-antigravity--replace-placeholder (buffer placeholder result params)
  "Replace PLACEHOLDER with RESULT in BUFFER, per the `:results' of PARAMS.
The token is searched for in the whole buffer rather than tracked with a
marker: the author keeps editing during the call, and the block may have
moved."
  (if (not (buffer-live-p buffer))
      (message "agy answer lost: the original buffer is closed")
    (with-current-buffer buffer
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (if (not (search-forward placeholder nil t))
              (message "Token %s not found: agy answer ignored" placeholder)
            (goto-char (match-beginning 0))
            (let ((case-fold-search t))
              (when (re-search-backward "^[ \t]*#\\+begin_src\\_>" nil t)
                (org-babel-insert-result result
                                         (cdr (assq :result-params params)))))))))))

(defun org-babel-antigravity--make-sentinel (context)
  "Build the sentinel of the process described by CONTEXT.
CONTEXT is a plist carrying the output buffers, the original org buffer, the
token to replace, the block parameters and the session name."
  (lambda (process _event)
    (when (memq (process-status process) '(exit signal))
      (let* ((output-buffer (plist-get context :output-buffer))
             (error-buffer (plist-get context :error-buffer))
             (outcome (org-babel-antigravity--interpret-output
                       (process-exit-status process)
                       (with-current-buffer output-buffer
                         (string-trim (buffer-string)))
                       (with-current-buffer error-buffer
                         (string-trim (buffer-string)))
                       (plist-get context :session-name))))
        (org-babel-antigravity--replace-placeholder
         (plist-get context :source-buffer)
         (plist-get context :placeholder)
         (plist-get outcome :text)
         (plist-get context :params))

        (kill-buffer output-buffer)
        (kill-buffer error-buffer)))))

(defun org-babel-antigravity--execute-asynchronously (arguments params session-name)
  "Start the CLI with ARGUMENTS without blocking Emacs.
Return the token inserted as the provisional result of the block; the
sentinel will replace it with the answer. PARAMS serves to reinsert the
result with the same `:results', SESSION-NAME to keep the conversation that
was opened."
  (let* ((placeholder (format "antigravity-running:%s" (org-id-uuid)))
         (output-buffer (generate-new-buffer " *ob-antigravity-output*"))
         (error-buffer (generate-new-buffer " *ob-antigravity-error*"))
         (context (list :output-buffer output-buffer
                        :error-buffer error-buffer
                        :source-buffer (current-buffer)
                        :placeholder placeholder
                        :params params
                        :session-name session-name))
         (process (make-process
                   :name "ob-antigravity"
                   :buffer output-buffer
                   :noquery t
                   :connection-type 'pipe
                   :command (cons org-babel-antigravity-command arguments)
                   ;; A dedicated pipe for stderr: without it the error
                   ;; messages mix with the JSON answer in the same buffer and
                   ;; make it unparseable. The `ignore' sentinel avoids the
                   ;; "Process finished" line that the default handling would
                   ;; write into the buffer.
                   :stderr (make-pipe-process :name "ob-antigravity-error"
                                              :buffer error-buffer
                                              :noquery t
                                              :sentinel #'ignore)
                   :sentinel nil)))
    (set-process-sentinel process (org-babel-antigravity--make-sentinel context))
    ;; The prompt is already in the command line: closing standard input keeps
    ;; the CLI from waiting for an input that will never come.
    (process-send-eof process)
    placeholder))

;;;###autoload
(defun org-babel-execute:antigravity (body params)
  "Send BODY as a prompt to the agy CLI and return its answer.
PARAMS carries the block headers. Called by `org-babel-execute-src-block'.
"
  (org-babel-antigravity--check-command)
  (let ((prompt (string-trim (org-babel-expand-body:antigravity body params))))
    (when (string-empty-p prompt)
      (user-error "Bloc antigravity vide : rien a envoyer"))
    (org-babel-antigravity--check-prompt-length prompt)

    (let ((arguments (append (org-babel-antigravity--build-arguments params)
                             (list (org-babel-antigravity--prompt-argument prompt))))
          (session-name (org-babel-antigravity--session-name params)))
      (if (org-babel-antigravity--async-p params)
          (org-babel-antigravity--execute-asynchronously arguments params session-name)
        (org-babel-antigravity--execute-synchronously arguments session-name)))))

(provide 'ob-antigravity)

;;; ob-antigravity.el ends here
