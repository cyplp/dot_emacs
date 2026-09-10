;;; test-mcp-explorer.el --- MCP explorer tests -*- lexical-binding: t -*-

;;; Commentary:

;; Run from the root of the repository:
;;
;;   emacs -Q --batch -l ert -l tests/test-mcp-explorer.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; The tests only exercise the pure layer of the module — schema
;; normalization, input conversion, payload assembly, input plan, formatting —
;; plus the locating under point, tested in a hand-built buffer.  No test
;; assumes a reachable MCP server, and none substitutes a function: the input
;; loop and the network call are out of reach by construction, which is the
;; accepted trade-off.
;;
;; The keymap assertions require `mcp-hub', absent under `emacs -Q' where
;; `elpa' is not in the `load-path'.  They skip themselves when the package is
;; missing, so that the suite stays green on a bare machine.

;;; Code:

(require 'ert)

(load (expand-file-name
       "../conf-mcp-explorer.el"
       (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

;;; Fixtures

(defconst my-mcp-explorer-test--search-schema
  '( :type "object"
     :properties ( :query (:type "string" :description "The searched term")
                   :limit (:type "integer"))
     :required ["query"])
  "Schema of a tool with one required and one optional argument.")

(defconst my-mcp-explorer-test--optional-first-schema
  '( :type "object"
     :properties ( :limit (:type "integer")
                   :query (:type "string"))
     :required ["query"])
  "Schema declaring the optional argument before the mandatory one.")

(defconst my-mcp-explorer-test--enum-schema
  '( :type "object"
     :properties (:format (:type "string" :enum ["json" "text"]))
     :required [])
  "Schema of a tool with imposed values.")

(defun my-mcp-explorer-test--names (arguments)
  "Return the list of the names of ARGUMENTS."
  (mapcar #'my-mcp-explorer-argument-name arguments))

(defun my-mcp-explorer-test--named (arguments name)
  "Return the descriptor named NAME among ARGUMENTS."
  (seq-find (lambda (argument)
              (equal name (my-mcp-explorer-argument-name argument)))
            arguments))

;;; Normalization of a tool schema

(ert-deftest my-mcp-explorer-test-tool-schema-lists-every-argument ()
  "The schema of a tool returns one descriptor per property."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-test--names arguments) '("query" "limit")))))

(ert-deftest my-mcp-explorer-test-tool-schema-keeps-type-and-description ()
  "The descriptor carries the type, the description and the obligation."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))
         (query (my-mcp-explorer-test--named arguments "query"))
         (limit (my-mcp-explorer-test--named arguments "limit")))
    (should (equal query '( :name "query" :type "string"
                            :description "The searched term"
                            :enum nil :default nil :required t)))
    (should (equal limit '( :name "limit" :type "integer"
                            :description nil :enum nil
                            :default nil :required nil)))))

(ert-deftest my-mcp-explorer-test-tool-schema-puts-required-first ()
  "The mandatory arguments come before the optional ones."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--optional-first-schema)))
    (should (equal (my-mcp-explorer-test--names arguments) '("query" "limit")))))

(ert-deftest my-mcp-explorer-test-tool-schema-keeps-enum ()
  "The imposed values are returned as a list."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))
         (format-argument (my-mcp-explorer-test--named arguments "format")))
    (should (equal (plist-get format-argument :enum) '("json" "text")))))

(ert-deftest my-mcp-explorer-test-tool-schema-without-properties-is-empty ()
  "An absent schema, or one without any property, returns the empty list."
  (should (equal (my-mcp-explorer-tool-arguments nil) '()))
  (should (equal (my-mcp-explorer-tool-arguments '(:type "object")) '())))

;;; Normalization of the arguments of a prompt

(ert-deftest my-mcp-explorer-test-prompt-arguments-carry-no-type ()
  "The arguments of a prompt return the same shape, without type."
  (let* ((arguments (my-mcp-explorer-prompt-arguments
                     [(:name "text" :description "To summarize" :required t)]))
         (text (my-mcp-explorer-test--named arguments "text")))
    (should (equal text '( :name "text" :type nil
                           :description "To summarize"
                           :enum nil :default nil :required t)))))

(ert-deftest my-mcp-explorer-test-prompt-arguments-read-json-false ()
  "A JSON-false `:required' returns an optional argument.
`:json-false' is non-nil in Lisp: testing it naively would make every prompt
argument mandatory."
  (let* ((arguments (my-mcp-explorer-prompt-arguments
                     [(:name "tone" :required :json-false)]))
         (tone (my-mcp-explorer-test--named arguments "tone")))
    (should-not (my-mcp-explorer-argument-required-p tone))))

(ert-deftest my-mcp-explorer-test-prompt-arguments-put-required-first ()
  "The mandatory arguments of a prompt come before the optional ones."
  (let ((arguments (my-mcp-explorer-prompt-arguments
                    [(:name "tone" :required :json-false)
                     (:name "text" :required t)])))
    (should (equal (my-mcp-explorer-test--names arguments) '("text" "tone")))))

(ert-deftest my-mcp-explorer-test-prompt-without-arguments-is-empty ()
  "A prompt without arguments returns the empty list."
  (should (equal (my-mcp-explorer-prompt-arguments nil) '()))
  (should (equal (my-mcp-explorer-prompt-arguments []) '())))

;;; Signature formatting

(ert-deftest my-mcp-explorer-test-signature-shows-name-and-description ()
  "The signature names the element and recalls its description."
  (let ((signature (my-mcp-explorer-format-signature
                     "search" "Full-text search"
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))))
    (should (string-match-p "\\`search$" (car (split-string signature "\n"))))
    (should (string-match-p "Full-text search" signature))))

(ert-deftest my-mcp-explorer-test-signature-labels-type-and-obligation ()
  "Each argument shows its type and its required or optional nature."
  (let ((signature (my-mcp-explorer-format-signature
                    "search" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))))
    (should (string-match-p "query (text, required)" signature))
    (should (string-match-p "The searched term" signature))
    (should (string-match-p "limit (integer, optional)" signature))))

(ert-deftest my-mcp-explorer-test-signature-lists-permitted-values ()
  "An argument with imposed values enumerates its values."
  (let ((signature (my-mcp-explorer-format-signature
                    "export" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))))
    (should (string-match-p "permitted values: json, text" signature))))

(ert-deftest my-mcp-explorer-test-signature-states-absence-of-arguments ()
  "An element without arguments says so, rather than showing an empty section."
  (let ((signature (my-mcp-explorer-format-signature "ping" nil '())))
    (should (string-match-p "No argument" signature))
    (should-not (string-match-p "Arguments:" signature))))

(ert-deftest my-mcp-explorer-test-signature-of-prompt-omits-type ()
  "The signature of a prompt announces no type."
  (let ((signature (my-mcp-explorer-format-signature
                    "resume" nil
                    (my-mcp-explorer-prompt-arguments
                     [(:name "text" :required t)]))))
    (should (string-match-p "text (required)" signature))))

;;; Conversion of an input to the expected type

(defun my-mcp-explorer-test--argument (type &rest overrides)
  "Build an argument descriptor of type TYPE.
OVERRIDES replaces the default fields."
  (apply #'my-mcp-explorer--make-argument
         :name "field" :type type :required t overrides))

(ert-deftest my-mcp-explorer-test-converts-text-verbatim ()
  "A text is passed as is, including without a declared type."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "string") "emacs")
                 "emacs"))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument nil) "emacs")
                 "emacs")))

(ert-deftest my-mcp-explorer-test-converts-integer ()
  "An integer is passed as a number."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "integer") "10")
                 10))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "integer") "-3")
                 -3)))

(ert-deftest my-mcp-explorer-test-rejects-non-numeric-integer ()
  "A non-numeric answer for an integer is rejected."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "integer") "a lot")
                :type 'user-error)
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "integer") "1.5")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-number ()
  "A decimal is passed as a number, exponential notation included."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "number") "1.5")
                 1.5))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "number") "2e3")
                 2000.0)))

(ert-deftest my-mcp-explorer-test-rejects-non-numeric-number ()
  "A non-numeric answer for a decimal is rejected."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "number") "a lot")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-boolean-to-json-value ()
  "A boolean goes out as `t' or `:json-false', never as a string."
  (should (eq (my-mcp-explorer-convert-argument
               (my-mcp-explorer-test--argument "boolean") "yes")
              t))
  (should (eq (my-mcp-explorer-convert-argument
               (my-mcp-explorer-test--argument "boolean") "no")
              my-mcp-explorer-false))
  (should-not (stringp (my-mcp-explorer-convert-argument
                        (my-mcp-explorer-test--argument "boolean") "no"))))

(ert-deftest my-mcp-explorer-test-rejects-unreadable-boolean ()
  "An answer that is neither yes nor no is rejected."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "boolean") "maybe")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-json-array ()
  "A JSON list fragment is parsed into a vector."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "array") "[1, 2]")
                 [1 2])))

(ert-deftest my-mcp-explorer-test-converts-json-object ()
  "A JSON object fragment is parsed into a hash table."
  (let ((value (my-mcp-explorer-convert-argument
                (my-mcp-explorer-test--argument "object") "{\"a\": 1}")))
    (should (hash-table-p value))
    (should (equal (gethash "a" value) 1))))

(ert-deftest my-mcp-explorer-test-keeps-empty-json-object-distinct ()
  "The empty object stays an object, it does not become null."
  (let ((value (my-mcp-explorer-convert-argument
                (my-mcp-explorer-test--argument "object") "{}")))
    (should (hash-table-p value))
    (should (zerop (hash-table-count value)))))

(ert-deftest my-mcp-explorer-test-rejects-invalid-json ()
  "An unreadable JSON fragment is rejected."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "object") "{oops")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-rejects-json-of-wrong-shape ()
  "A list where an object is expected is rejected, and conversely."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "object") "[1]")
                :type 'user-error)
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "array") "{}")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-rejects-value-outside-enum ()
  "A value outside the permitted values is rejected."
  (let ((argument (my-mcp-explorer-test--argument
                   "string" :enum '("json" "text"))))
    (should (equal (my-mcp-explorer-convert-argument argument "json") "json"))
    (should-error (my-mcp-explorer-convert-argument argument "yaml")
                  :type 'user-error)))

;;; Payload assembly

(ert-deftest my-mcp-explorer-test-payload-carries-converted-values ()
  "The payload carries the converted values, in the order of the arguments."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" "10"))
                   '(:query "emacs" :limit 10)))))

(ert-deftest my-mcp-explorer-test-payload-omits-blank-optional ()
  "An optional argument left empty does not appear in the payload."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" ""))
                   '(:query "emacs")))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" "   "))
                   '(:query "emacs")))))

(ert-deftest my-mcp-explorer-test-payload-refuses-blank-required ()
  "A mandatory argument left empty interrupts before any call."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should-error (my-mcp-explorer-build-payload arguments '("" "10"))
                  :type 'user-error)))

(ert-deftest my-mcp-explorer-test-payload-of-argumentless-tool-is-empty ()
  "A tool without arguments produces an empty payload."
  (should (null (my-mcp-explorer-build-payload '() '()))))

(ert-deftest my-mcp-explorer-test-payload-guards-against-answer-mismatch ()
  "A number of answers different from the number of arguments is an error.
It is a programming mistake, not a payload to truncate silently."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should-error (my-mcp-explorer-build-payload arguments '("emacs")))))

;;; Input plan

(ert-deftest my-mcp-explorer-test-read-plan-prompts-with-type-and-obligation ()
  "The prompt carries the name, the type and the required or optional nature."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))
         (query (my-mcp-explorer-test--named arguments "query"))
         (limit (my-mcp-explorer-test--named arguments "limit")))
    (should (equal (plist-get (my-mcp-explorer-read-plan query) :prompt)
                   "query (text, required): "))
    (should (equal (plist-get (my-mcp-explorer-read-plan limit) :prompt)
                   "limit (integer, optional): "))))

(ert-deftest my-mcp-explorer-test-read-plan-completes-on-enum ()
  "An imposed value is read with completion on its own values only."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))
         (plan (my-mcp-explorer-read-plan
                (my-mcp-explorer-test--named arguments "format"))))
    (should (eq (plist-get plan :reader) 'completing-read))
    (should (equal (plist-get plan :collection) '("json" "text")))))

(ert-deftest my-mcp-explorer-test-read-plan-completes-on-boolean ()
  "A boolean is read with completion on yes and no."
  (let ((plan (my-mcp-explorer-read-plan
               (my-mcp-explorer-test--argument "boolean"))))
    (should (eq (plist-get plan :reader) 'completing-read))
    (should (equal (plist-get plan :collection) '("yes" "no")))))

(ert-deftest my-mcp-explorer-test-read-plan-reads-plain-text ()
  "An argument without any constraint is read in the free minibuffer."
  (dolist (type '("string" "integer" "number" "array" "object" nil))
    (let ((plan (my-mcp-explorer-read-plan
                 (my-mcp-explorer-test--argument type))))
      (should (eq (plist-get plan :reader) 'read-string))
      (should (null (plist-get plan :collection))))))

(ert-deftest my-mcp-explorer-test-read-plan-offers-only-convertible-answers ()
  "Every offered answer is accepted by the converter of the type.
As prompt and conversion come from the same line of the type table, they
must never diverge."
  (dolist (argument (list (my-mcp-explorer-test--argument "boolean")
                          (my-mcp-explorer-test--argument
                           "string" :enum '("json" "text"))))
    (dolist (answer (plist-get (my-mcp-explorer-read-plan argument) :collection))
      (should (my-mcp-explorer-convert-argument argument answer)))))

;;; Result formatting

(ert-deftest my-mcp-explorer-test-result-shows-text-then-raw-json ()
  "The view shows the readable content, then the complete answer in JSON."
  (let ((view (my-mcp-explorer-format-result
               '(:content [(:type "text" :text "three results")])
               "three results")))
    (should (string-match-p "three results" view))
    (should (string-match-p "Raw answer" view))
    (should (< (string-match "three results" view)
               (string-match "Raw answer" view)))
    (should (string-match-p "\"content\"" view))))

(ert-deftest my-mcp-explorer-test-result-announces-server-error ()
  "An answer carrying `:isError' is announced, content included."
  (let ((view (my-mcp-explorer-format-result
               '(:isError t :content [(:type "text" :text "missing index")])
               "missing index")))
    (should (string-match-p "error" view))
    (should (string-match-p "missing index" view))))

(ert-deftest my-mcp-explorer-test-result-ignores-json-false-error-flag ()
  "A JSON-false `:isError' announces no error."
  (let ((view (my-mcp-explorer-format-result
               '(:isError :json-false :content []) "nothing")))
    (should-not (string-match-p "answered an error" view))))

(ert-deftest my-mcp-explorer-test-result-states-absence-of-text ()
  "An answer without textual content says so rather than staying silent."
  (let ((view (my-mcp-explorer-format-result '(:content []) "")))
    (should (string-match-p "no textual content" view))))

(ert-deftest my-mcp-explorer-test-result-buffer-name-is-stable ()
  "Replaying the same element targets the same buffer, stacking no second one."
  (should (equal (my-mcp-explorer-result-buffer-name "local" "search")
                 (my-mcp-explorer-result-buffer-name "local" "search")))
  (should-not (equal (my-mcp-explorer-result-buffer-name "local" "search")
                     (my-mcp-explorer-result-buffer-name "local" "ping"))))

;;; Readable content of a prompt answer

(defconst my-mcp-explorer-test--prompt-response
  '(:messages [( :role "user"
                 :content (:type "text" :text "Frame the subject"))
               ( :role "assistant"
                 :content (:type "text" :text "Give the instruction"))])
  "Answer to `prompts/get' carrying two messages.")

(ert-deftest my-mcp-explorer-test-prompt-text-keeps-message-order ()
  "The messages appear in the order returned by the server."
  (let ((view (my-mcp-explorer-prompt-messages-text
               my-mcp-explorer-test--prompt-response)))
    (should (string-match-p "Frame the subject" view))
    (should (string-match-p "Give the instruction" view))
    (should (< (string-match "Frame the subject" view)
               (string-match "Give the instruction" view)))))

(ert-deftest my-mcp-explorer-test-prompt-text-names-each-role ()
  "Each message is attributed to its role."
  (let ((view (my-mcp-explorer-prompt-messages-text
               my-mcp-explorer-test--prompt-response)))
    (should (string-match-p "\\[user\\]" view))
    (should (string-match-p "\\[assistant\\]" view))))

(ert-deftest my-mcp-explorer-test-prompt-text-flags-non-textual-content ()
  "A non-textual content is reported rather than silently omitted."
  (let ((view (my-mcp-explorer-prompt-messages-text
               '(:messages [(:role "user" :content (:type "image" :data "..."))]))))
    (should (string-match-p "non-textual image content" view))))

(ert-deftest my-mcp-explorer-test-prompt-text-reads-content-arrays ()
  "A message carrying several content blocks returns them all."
  (let ((view (my-mcp-explorer-prompt-messages-text
               '(:messages [( :role "user"
                              :content [(:type "text" :text "one")
                                        (:type "text" :text "two")])]))))
    (should (string-match-p "one" view))
    (should (string-match-p "two" view))))

(ert-deftest my-mcp-explorer-test-prompt-without-messages-is-empty ()
  "An answer without messages returns an empty string, without error."
  (should (equal (my-mcp-explorer-prompt-messages-text '(:messages [])) ""))
  (should (equal (my-mcp-explorer-prompt-messages-text nil) "")))

(ert-deftest my-mcp-explorer-test-prompt-result-view-shows-messages ()
  "The result view of a prompt shows its messages then the raw JSON."
  (let ((view (my-mcp-explorer-format-result
               my-mcp-explorer-test--prompt-response
               (my-mcp-explorer-prompt-messages-text
                my-mcp-explorer-test--prompt-response))))
    (should (string-match-p "Frame the subject" view))
    (should (string-match-p "Raw answer" view))
    (should (string-match-p "\"messages\"" view))))

;;; Routing by element kind

(ert-deftest my-mcp-explorer-test-routes-tool-and-prompt ()
  "Each element kind targets its asynchronous call."
  (should (eq (my-mcp-explorer--caller 'tool) #'mcp-async-call-tool))
  (should (eq (my-mcp-explorer--caller 'prompt) #'mcp-async-get-prompt)))

(ert-deftest my-mcp-explorer-test-refuses-unknown-kind ()
  "An unknown kind is rejected by `user-error', not by a bare error."
  (should-error (my-mcp-explorer--caller 'resource) :type 'user-error))

(ert-deftest my-mcp-explorer-test-reads-prompt-response-through-routing ()
  "The routing does return the text of the messages for a prompt."
  (should (string-match-p
           "Frame the subject"
           (my-mcp-explorer--readable-text
            'prompt my-mcp-explorer-test--prompt-response))))

;;; Result view and failure report

(ert-deftest my-mcp-explorer-test-display-reuses-its-buffer ()
  "Replaying an element replaces the content instead of stacking a view."
  (let ((buffer-name "*MCP test: reuse*"))
    (unwind-protect
        (progn
          (my-mcp-explorer--display buffer-name "first")
          (let ((before (length (buffer-list))))
            (my-mcp-explorer--display buffer-name "second")
            (should (= before (length (buffer-list)))))
          (with-current-buffer buffer-name
            (should (string-match-p "second" (buffer-string)))
            (should-not (string-match-p "first" (buffer-string)))))
      (when (get-buffer buffer-name) (kill-buffer buffer-name)))))

(ert-deftest my-mcp-explorer-test-display-is-read-only ()
  "The view opens in `special-mode', hence read-only."
  (let ((buffer-name "*MCP test: read only*"))
    (unwind-protect
        (progn
          (my-mcp-explorer--display buffer-name "content")
          (with-current-buffer buffer-name
            (should (eq major-mode 'special-mode))
            (should buffer-read-only)))
      (when (get-buffer buffer-name) (kill-buffer buffer-name)))))

(ert-deftest my-mcp-explorer-test-transport-failure-names-code-and-message ()
  "A transport failure is reported as a readable message, without a trace.
The reference server returns unknown tools as an application answer: this
path only triggers on a real JSON-RPC error, hence a check on the callback
itself."
  (let ((inhibit-message t))
    (with-current-buffer (get-buffer-create "*Messages*")
      (let ((inhibit-read-only t))
        (erase-buffer))
      (funcall (my-mcp-explorer--on-failure "local" "search")
               -32601 "unknown method")
      (let ((log (buffer-string)))
        (should (string-match-p "-32601" log))
        (should (string-match-p "unknown method" log))
        (should (string-match-p "search" log))
        (should (string-match-p "local" log))))))

;;; Default values

(defconst my-mcp-explorer-test--defaults-schema
  '( :type "object"
     :properties ( :limit (:type "integer" :default 50)
                   :raw (:type "boolean" :default :json-false)
                   :verbose (:type "boolean" :default t)
                   :prefix (:type "string" :default "")
                   :start (:type "string" :default nil)
                   :ip (:type "string")))
  "Schema covering each form of default value, JSON `null' included.")

(defun my-mcp-explorer-test--defaults-argument (name)
  "Return the descriptor NAME of the defaults schema."
  (my-mcp-explorer-test--named
   (my-mcp-explorer-tool-arguments my-mcp-explorer-test--defaults-schema)
   name))

(ert-deftest my-mcp-explorer-test-label-shows-numeric-default ()
  "A numeric default appears in the label of the argument."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "limit"))
                 "(integer, optional, default 50)")))

(ert-deftest my-mcp-explorer-test-label-shows-false-default ()
  "A false default is displayed, it is not confused with an absence.
`:json-false' is non-nil: it is a default value in its own right."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "raw"))
                 "(boolean, optional, default no)"))
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "verbose"))
                 "(boolean, optional, default yes)")))

(ert-deftest my-mcp-explorer-test-label-shows-empty-string-default ()
  "An empty-string default stays visible thanks to the quotes."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "prefix"))
                 "(text, optional, default \"\")")))

(ert-deftest my-mcp-explorer-test-label-hides-null-and-absent-default ()
  "A `null' or absent default adds no mention."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "start"))
                 "(text, optional)"))
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "ip"))
                 "(text, optional)")))

(ert-deftest my-mcp-explorer-test-signature-shows-defaults ()
  "The signature carries the default values of the schema."
  (let ((signature (my-mcp-explorer-format-signature
                    "alerts" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--defaults-schema))))
    (should (string-match-p "limit (integer, optional, default 50)" signature))
    (should (string-match-p "raw (boolean, optional, default no)" signature))))

(ert-deftest my-mcp-explorer-test-prompt-shows-default ()
  "The input prompt also announces the default: it says what an empty answer
will produce."
  (should (equal (plist-get (my-mcp-explorer-read-plan
                             (my-mcp-explorer-test--defaults-argument "limit"))
                            :prompt)
                 "limit (integer, optional, default 50): ")))

(ert-deftest my-mcp-explorer-test-default-is-never-sent ()
  "Displaying a default does not send it: an empty optional stays omitted.
The server applies its own default, this module does not guess it in its
place."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--defaults-schema)))
    (should (null (my-mcp-explorer-build-payload
                   arguments (make-list (length arguments) ""))))))

(ert-deftest my-mcp-explorer-test-format-value-encodes-structures ()
  "A structured default is returned as compact JSON, on a single line."
  (should (equal (my-mcp-explorer-format-value [1 2]) "[1,2]"))
  (should-not (string-match-p "\n" (my-mcp-explorer-format-value [1 2]))))

;;; Locating the element under point

(defun my-mcp-explorer-test--detail-buffer ()
  "Build a buffer reproducing the structure of the `mcp-hub' rendering.
Only the properties the locating reads matter: the server name at
`point-min', the `outline-1' face of the headers, the bullets of the
elements."
  (let ((buffer (generate-new-buffer " *mcp-explorer-test-detail*")))
    (with-current-buffer buffer
      (insert (propertize "local\n" 'mcp-server-name "local"))
      (insert "-----\n\n")
      (insert (propertize "Status:\n" 'face 'outline-1))
      (insert "  Running: Yes\n\n")
      (insert (propertize "Tools (2):\n" 'face 'outline-1))
      (insert (propertize "  • search" 'face 'outline-2) "\n")
      (insert "    Full-text search\n")
      (insert (propertize "  • ping" 'face 'outline-2) "\n\n")
      (insert (propertize "Resources (1):\n" 'face 'outline-1))
      (insert (propertize "  • Journal" 'face 'outline-2)
              " (" (propertize "file:///journal" 'face 'font-lock-string-face) ")\n\n")
      (insert (propertize "Prompts (1):\n" 'face 'outline-1))
      (insert (propertize "  • resume" 'face 'outline-2) "\n"))
    buffer))

(defmacro my-mcp-explorer-test--at-line (pattern &rest body)
  "Execute BODY in the detail buffer, point on the line PATTERN."
  (declare (indent 1))
  `(let ((buffer (my-mcp-explorer-test--detail-buffer)))
     (unwind-protect
         (with-current-buffer buffer
           (goto-char (point-min))
           (re-search-forward ,pattern)
           (beginning-of-line)
           ,@body)
       (kill-buffer buffer))))

(ert-deftest my-mcp-explorer-test-locates-tool-under-point ()
  "A bullet of the tools section returns an element of kind `tool'."
  (my-mcp-explorer-test--at-line "• search"
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind tool :name "search")))))

(ert-deftest my-mcp-explorer-test-locates-prompt-under-point ()
  "A bullet of the prompts section returns an element of kind `prompt'."
  (my-mcp-explorer-test--at-line "• resume"
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind prompt :name "resume")))))

(ert-deftest my-mcp-explorer-test-ignores-resources ()
  "A resource bullet returns nothing: it is not executable."
  (my-mcp-explorer-test--at-line "• Journal"
    (should-not (my-mcp-explorer-element-at-point))))

(ert-deftest my-mcp-explorer-test-ignores-lines-without-bullet ()
  "A line without a bullet returns nothing, even in a tools section."
  (my-mcp-explorer-test--at-line "Full-text search"
    (should-not (my-mcp-explorer-element-at-point)))
  (my-mcp-explorer-test--at-line "Running: Yes"
    (should-not (my-mcp-explorer-element-at-point))))

(ert-deftest my-mcp-explorer-test-locates-tool-from-mid-line ()
  "The locating does not depend on the column of point."
  (my-mcp-explorer-test--at-line "• search"
    (end-of-line)
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind tool :name "search")))))

;;; Explicit refusals

(ert-deftest my-mcp-explorer-test-refuses-outside-detail-buffer ()
  "Outside a detail buffer, the signature is refused by `user-error'."
  (with-temp-buffer
    (insert "  • search\n")
    (goto-char (point-min))
    (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error)))

(ert-deftest my-mcp-explorer-test-refuses-when-nothing-under-point ()
  "On a line without an element, the signature is refused by `user-error'."
  (my-mcp-explorer-test--at-line "Running: Yes"
    (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error)))

(ert-deftest my-mcp-explorer-test-refuses-when-server-disconnected ()
  "On a disconnected server, the signature is refused by naming it."
  (my-mcp-explorer-test--at-line "• search"
    (let ((mcp-server-connections (make-hash-table :test #'equal)))
      (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error))))

;;; Bindings of the detail buffer

(defun my-mcp-explorer-test--load-mcp-hub ()
  "Load `mcp-hub' from the installed packages, or return nil."
  (require 'package)
  (package-initialize)
  (require 'mcp-hub nil t))

(defmacro my-mcp-explorer-test--in-detail-mode (&rest body)
  "Execute BODY in a buffer where `mcp-hub-detail-mode' is active.
Enabling it is indispensable: `mcp.el' puts its `define-key' calls in the
body of `define-derived-mode' (mcp-hub.el:456), so that the keymap stays
empty as long as the mode has not run at least once."
  (declare (indent 0))
  `(with-temp-buffer
     (mcp-hub-detail-mode)
     ,@body))

(ert-deftest my-mcp-explorer-test-binds-signature-without-stealing-keys ()
  "`s' opens the signature, and the original keys stay intact."
  (unless (my-mcp-explorer-test--load-mcp-hub)
    (ert-skip "mcp-hub absent from this environment"))
  (my-mcp-explorer-test--in-detail-mode
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "s"))
                #'my-mcp-explorer-show-signature-at-point))
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "x"))
                #'my-mcp-explorer-execute-at-point))
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "n"))
                #'mcp-hub-detail-next-heading))
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "p"))
                #'mcp-hub-detail-previous-heading))
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "RET"))
                #'mcp-hub-detail-reading-resource))
    (should (eq (lookup-key mcp-hub-detail-mode-map (kbd "g"))
                #'mcp-hub-detail-refresh))))

(provide 'test-mcp-explorer)

;;; test-mcp-explorer.el ends here
