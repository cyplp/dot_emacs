;;; ob-claude.el --- org-babel blocks executed by the claude CLI -*- lexical-binding: t -*-

;;; Commentary:

;; Lets you write a prompt in an org block and send it to the `claude' CLI with
;; `C-c C-c':
;;
;;   #+begin_src claude :model sonnet
;;   Summarize the role of this repository.
;;   #+end_src
;;
;; The block body is the prompt, the answer becomes the result of the block.
;;
;; The call is asynchronous by default: an answer takes tens of seconds and
;; Emacs is single-threaded, so a synchronous call would freeze the editor for
;; that whole time. The block first receives a token, replaced by the answer
;; when the process ends. `:async no' makes the call blocking, useful in batch
;; mode or for the tests.
;;
;; The prompt goes through standard input and never through the command line: a
;; long prompt exceeds the system argument limit, and a prompt containing
;; quotes or newlines does not have to be escaped.
;;
;; Headers recognized, in addition to org's own:
;;
;;   :model           model alias or full name (sonnet, opus, ...)
;;   :effort          effort level (low, medium, high, xhigh, max)
;;   :agent           agent to use for the session
;;   :system          text appended to the system prompt
;;   :permission-mode plan, acceptEdits, bypassPermissions, ...
;;   :allowed-tools   list of allowed tools, separated by spaces
;;   :add-dir         extra accessible directories
;;   :session         name of a conversation followed from one block to the next
;;   :async           yes (default) or no
;;   :dir             working directory of the CLI, handled by org itself

;;; Code:

(require 'ob)
(require 'org-id)
(require 'subr-x)

;; --- Settings ---------------------------------------------------------------

(defgroup org-babel-claude nil
  "Execution of org-babel blocks by the claude CLI."
  :group 'org-babel)

(defcustom org-babel-claude-command "claude"
  "Name or path of the Claude Code CLI executable."
  :type 'string
  :group 'org-babel-claude)

(defcustom org-babel-claude-base-arguments '("--print")
  "Arguments passed on every call, before those derived from the headers.
`--print' is indispensable: without it the CLI opens a full-screen
interactive session, which makes no sense behind a pipe."
  :type '(repeat string)
  :group 'org-babel-claude)

;; A block without an answer is a visible error; a block that modifies files
;; behind the author's back is not. The default result is therefore a drawer —
;; the answer is free text, often multiline and in markdown — and export
;; evaluates nothing.
(defvar org-babel-default-header-args:claude
  '((:results . "drawer replace")
    (:exports . "both")
    (:eval . "never-export"))
  "Default headers of the `claude' blocks.")

;; --- Translation of the headers into arguments ------------------------------

(defconst org-babel-claude--argument-by-header
  '((:model . "--model")
    (:effort . "--effort")
    (:agent . "--agent")
    (:system . "--append-system-prompt")
    (:permission-mode . "--permission-mode")
    (:allowed-tools . "--allowed-tools")
    (:add-dir . "--add-dir"))
  "Mapping between block header and CLI option.
Every header present adds its option followed by its value.")

(defun org-babel-claude--header-value (header params)
  "Return the value of HEADER in PARAMS, as a string.
Return nil if the header is absent or empty. Org reads the header values with
`org-babel-read', which can yield a number or a symbol: the value is
reformatted before landing in a command line."
  (let ((value (cdr (assq header params))))
    (when value
      (let ((text (string-trim (format "%s" value))))
        (unless (string-empty-p text)
          text)))))

(defun org-babel-claude--session-name (params)
  "Return the session name declared in PARAMS, or nil.
Org gives the value \"none\" when no session is requested."
  (let ((session (org-babel-claude--header-value :session params)))
    (unless (member session '(nil "none"))
      session)))

(defvar org-babel-claude--session-identifiers (make-hash-table :test #'equal)
  "CLI conversation identifier for each session name.
The first block of a session creates the identifier, the following ones
resume the same conversation: the context of the previous blocks stays
available.")

(defvar org-babel-claude--started-sessions (make-hash-table :test #'equal)
  "Sessions in which a block has already run successfully.
A conversation can only be resumed once created: as long as no block has
completed, the identifier must be created and not resumed.")

(defun org-babel-claude--session-arguments (session-name)
  "Return the CLI arguments that resume the SESSION-NAME conversation."
  (let ((identifier (or (gethash session-name org-babel-claude--session-identifiers)
                        (puthash session-name (org-id-uuid)
                                 org-babel-claude--session-identifiers))))
    (if (gethash session-name org-babel-claude--started-sessions)
        (list "--resume" identifier)
      (list "--session-id" identifier))))

(defun org-babel-claude-reset-session (session-name)
  "Forget the conversation associated with SESSION-NAME.
The next block of that session starts again from an empty context."
  (interactive (list (completing-read
                      "Session claude : "
                      (hash-table-keys org-babel-claude--session-identifiers)
                      nil t)))
  (remhash session-name org-babel-claude--session-identifiers)
  (remhash session-name org-babel-claude--started-sessions)
  (message "Session claude %s reinitialisee" session-name))

(defun org-babel-claude--build-arguments (params)
  "Build the CLI argument list from PARAMS."
  (let ((arguments (copy-sequence org-babel-claude-base-arguments)))
    (dolist (entry org-babel-claude--argument-by-header)
      (let ((value (org-babel-claude--header-value (car entry) params)))
        (when value
          (setq arguments (append arguments (list (cdr entry) value))))))

    (let ((session-name (org-babel-claude--session-name params)))
      (when session-name
        (setq arguments
              (append arguments (org-babel-claude--session-arguments session-name)))))

    arguments))

;; --- Block body -------------------------------------------------------------

(defun org-babel-expand-body:claude (body params)
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

(defun org-babel-claude--async-p (params)
  "Tell whether the block described by PARAMS must run in the background."
  (not (member (org-babel-claude--header-value :async params) '("no" "nil"))))

(defun org-babel-claude--check-command ()
  "Check that the CLI is reachable, or signal an explicit error."
  (unless (executable-find org-babel-claude-command)
    (user-error "Executable %s not found in `exec-path'"
                org-babel-claude-command)))

(defun org-babel-claude--failure-message (exit-code error-output)
  "Compose the failure message of a call exited with EXIT-CODE and ERROR-OUTPUT."
  (format "claude a echoue (code %s)%s"
          exit-code
          (if (string-empty-p error-output)
              ""
            (concat " : " error-output))))

(defun org-babel-claude--execute-synchronously (prompt arguments session-name)
  "Call the CLI with ARGUMENTS and PROMPT, and return its answer.
SESSION-NAME, when non-nil, is marked as started on success.
Blocks Emacs until the call ends."
  (let ((error-file (make-temp-file "ob-claude-error")))
    (unwind-protect
        (with-temp-buffer
          (insert prompt)
          (let ((exit-code (apply #'call-process-region
                                  (point-min) (point-max)
                                  org-babel-claude-command
                                  'delete (list t error-file) nil
                                  arguments)))
            (if (equal exit-code 0)
                (progn
                  (when session-name
                    (puthash session-name t org-babel-claude--started-sessions))
                  (string-trim (buffer-string)))
              (user-error "%s"
                          (org-babel-claude--failure-message
                           exit-code
                           (string-trim
                            (with-temp-buffer
                              (insert-file-contents error-file)
                              (buffer-string))))))))
      (delete-file error-file))))

(defun org-babel-claude--replace-placeholder (buffer placeholder result params)
  "Replace PLACEHOLDER with RESULT in BUFFER, per the `:results' of PARAMS.
The token is searched for in the whole buffer rather than tracked with a
marker: the author keeps editing during the call, and the block may have
moved."
  (if (not (buffer-live-p buffer))
      (message "claude answer lost: the original buffer is closed")
    (with-current-buffer buffer
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (if (not (search-forward placeholder nil t))
              (message "Token %s not found: claude answer ignored" placeholder)
            (goto-char (match-beginning 0))
            (let ((case-fold-search t))
              (when (re-search-backward "^[ \t]*#\\+begin_src\\_>" nil t)
                (org-babel-insert-result result
                                         (cdr (assq :result-params params)))))))))))

(defun org-babel-claude--make-sentinel (context)
  "Build the sentinel of the process described by CONTEXT.
CONTEXT is a plist carrying the output buffers, the original org buffer, the
token to replace, the block parameters and the session name."
  (lambda (process _event)
    (when (memq (process-status process) '(exit signal))
      (let* ((output-buffer (plist-get context :output-buffer))
             (error-buffer (plist-get context :error-buffer))
             (exit-code (process-exit-status process))
             (output (with-current-buffer output-buffer
                       (string-trim (buffer-string))))
             (error-output (with-current-buffer error-buffer
                             (string-trim (buffer-string))))
             (session-name (plist-get context :session-name)))
        (when (and (equal exit-code 0) session-name)
          (puthash session-name t org-babel-claude--started-sessions))

        (org-babel-claude--replace-placeholder
         (plist-get context :source-buffer)
         (plist-get context :placeholder)
         (if (equal exit-code 0)
             output
           (org-babel-claude--failure-message exit-code error-output))
         (plist-get context :params))

        (kill-buffer output-buffer)
        (kill-buffer error-buffer)))))

(defun org-babel-claude--execute-asynchronously (prompt arguments params session-name)
  "Start the CLI with ARGUMENTS and PROMPT without blocking Emacs.
Return the token inserted as the provisional result of the block; the
sentinel will replace it with the answer. PARAMS serves to reinsert the
result with the same `:results', SESSION-NAME to mark the conversation as
started."
  (let* ((placeholder (format "claude-running:%s" (org-id-uuid)))
         (output-buffer (generate-new-buffer " *ob-claude-output*"))
         (error-buffer (generate-new-buffer " *ob-claude-error*"))
         (context (list :output-buffer output-buffer
                        :error-buffer error-buffer
                        :source-buffer (current-buffer)
                        :placeholder placeholder
                        :params params
                        :session-name session-name))
         (process (make-process
                   :name "ob-claude"
                   :buffer output-buffer
                   :noquery t
                   :connection-type 'pipe
                   :command (cons org-babel-claude-command arguments)
                   ;; A dedicated pipe for stderr: without it the error
                   ;; messages mix with the answer in the same buffer.
                   ;; The `ignore' sentinel avoids the "Process finished" line
                   ;; that the default handling would write into the buffer.
                   :stderr (make-pipe-process :name "ob-claude-error"
                                              :buffer error-buffer
                                              :noquery t
                                              :sentinel #'ignore)
                   :sentinel nil)))
    (set-process-sentinel process (org-babel-claude--make-sentinel context))
    (process-send-string process prompt)
    (process-send-eof process)
    placeholder))

;;;###autoload
(defun org-babel-execute:claude (body params)
  "Send BODY as a prompt to the claude CLI and return its answer.
PARAMS carries the block headers. Called by `org-babel-execute-src-block'.
"
  (org-babel-claude--check-command)
  (let ((prompt (string-trim (org-babel-expand-body:claude body params))))
    (when (string-empty-p prompt)
      (user-error "Bloc claude vide : rien a envoyer"))

    (let ((arguments (org-babel-claude--build-arguments params))
          (session-name (org-babel-claude--session-name params)))
      (if (org-babel-claude--async-p params)
          (org-babel-claude--execute-asynchronously prompt arguments params session-name)
        (org-babel-claude--execute-synchronously prompt arguments session-name)))))

(provide 'ob-claude)

;;; ob-claude.el ends here
