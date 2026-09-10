;;; conf-mcp-explorer.el --- Executable exploration of MCP servers -*- lexical-binding: t -*-

;;; Commentary:

;; The detail buffer of `mcp-hub' can show what an MCP server exposes — tools,
;; resources, templates, prompts — and read a resource with `RET'.  It stops
;; there: nothing in it calls a tool, and the argument schema of a tool is
;; never displayed.  You see that a tool exists, never what to call it with.
;;
;; This module adds two keys to that buffer, without changing its rendering:
;;
;;   s  signature of the tool or prompt under point
;;   x  execution of that tool or prompt
;;
;; The module splits into two layers, and this separation is structural, not
;; cosmetic: the repository forbids mocks, and no MCP server is guaranteed
;; reachable at test time.  Only a layer without input/output is therefore
;; testable.
;;
;;   - Pure layer: normalization of a schema into argument descriptors,
;;     conversion of an input to the expected type, assembly of the payload,
;;     input plan, formatting of the signature and of the result.
;;   - Interactive layer: the minibuffer reading loop, the network call, the
;;     display of the buffers.  It decides nothing.
;;
;; The server wiring — address and token — stays entirely in `conf-mcp.el' and
;; `secret.el'.  This module knows nothing about it.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)

;; These symbols belong to `mcp.el' / `mcp-hub.el', loaded on demand.
;; We only tell the compiler they exist: the module must stay loadable without
;; them, and that is what lets the tests run in batch mode.
(defvar mcp-server-connections)
(defvar mcp-hub-detail-mode-map)
(declare-function mcp--tools "mcp" (connection))
(declare-function mcp--prompts "mcp" (connection))
(declare-function mcp--parse-tool-call-result "mcp" (res))
(declare-function mcp-async-call-tool "mcp" (connection name arguments callback error-callback))
(declare-function mcp-async-get-prompt "mcp" (connection name arguments callback error-callback))

;; --- Protocol types ---------------------------------------------------------

;; `jsonrpc' decodes JSON false as `:json-false' and null as nil
;; (jsonrpc.el:632).  Any boolean value built here must therefore be `t' or
;; `:json-false' to serialize back correctly — never nil, which would go out
;; as `null'.
(defconst my-mcp-explorer-false :json-false
  "Lisp value that `jsonrpc' serializes as JSON false.")

(defconst my-mcp-explorer--boolean-answers '("yes" "no")
  "Answers offered for a boolean argument.
`y-or-n-p' would be more direct but cannot return \"no answer\": an optional
boolean would become impossible to omit.  Going through completion moreover
keeps the same contract for every type — the reader returns a string, the
converter turns it into a value.")

(defconst my-mcp-explorer--type-table
  '(("string"  :label "text"    :convert my-mcp-explorer--to-string)
    ("integer" :label "integer" :convert my-mcp-explorer--to-integer)
    ("number"  :label "number"  :convert my-mcp-explorer--to-number)
    ("boolean" :label "boolean" :convert my-mcp-explorer--to-boolean
     :answers my-mcp-explorer--boolean-answers)
    ("array"   :label "list"    :convert my-mcp-explorer--to-array)
    ("object"  :label "object"  :convert my-mcp-explorer--to-object))
  "Describe each type of the JSON schema.
Each entry carries the label of the type, its converter and the answers
offered at input time.  Label, reading and conversion come from the same
line: separating them would one day allow offering a choice the converter
rejects.  An absent or unknown type falls back on text — the prompts announce
no type, and a schema may declare one this module ignores.")

(defun my-mcp-explorer--type-entry (type)
  "Return the entry of `my-mcp-explorer--type-table' for TYPE.
Return the text entry when TYPE is nil or unknown."
  (or (assoc type my-mcp-explorer--type-table)
      (assoc "string" my-mcp-explorer--type-table)))

(defun my-mcp-explorer--type-label (type)
  "Return the readable label of TYPE, or nil if TYPE is absent."
  (when type
    (plist-get (cdr (my-mcp-explorer--type-entry type)) :label)))

(defun my-mcp-explorer-truthy-p (value)
  "True when VALUE is true in the JSON sense.
`:json-false' is a non-nil value in Lisp: testing it with `if' alone would
make every boolean of the protocol true."
  (and value (not (eq value my-mcp-explorer-false))))

;; --- Argument descriptors ---------------------------------------------------

;; Tools carry a complete `inputSchema', prompts a plain array of arguments
;; without type.  Both forms converge here into a single descriptor, the only
;; form the rest of the module knows.

(cl-defun my-mcp-explorer--make-argument (&key name type description enum
                                               default required)
  "Build the descriptor of an argument.
NAME is its name, TYPE its type from the JSON schema or nil, DESCRIPTION its
help text or nil, ENUM the list of its only permitted values or nil, DEFAULT
the value the server keeps in the absence of an input, REQUIRED non-nil when
the argument is mandatory.

A nil DEFAULT covers indifferently the absent property and the JSON `null' —
both say the same thing here: no default value to show.  A false default, on
the other hand, arrives as `:json-false', which is non-nil, and therefore
stays displayed."
  (list :name name
        :type type
        :description description
        :enum enum
        :default default
        :required (and required t)))

(defun my-mcp-explorer-argument-name (argument)
  "Return the name of ARGUMENT."
  (plist-get argument :name))

(defun my-mcp-explorer-argument-required-p (argument)
  "True when ARGUMENT is mandatory."
  (plist-get argument :required))

(defun my-mcp-explorer--sequence-to-list (value)
  "Return VALUE as a list, be it a vector, a list or nil.
JSON decoding returns the arrays as vectors."
  (append value nil))

(defun my-mcp-explorer--required-first (arguments)
  "Return ARGUMENTS reordered, the mandatory ones first.
The original order is preserved inside each group."
  (append (seq-filter #'my-mcp-explorer-argument-required-p arguments)
          (seq-remove #'my-mcp-explorer-argument-required-p arguments)))

(defun my-mcp-explorer--property-name (key)
  "Return the argument name carried by KEY, a keyword from the JSON decoding."
  (substring (symbol-name key) 1))

(defun my-mcp-explorer-tool-arguments (input-schema)
  "Normalize INPUT-SCHEMA into a list of descriptors, the mandatory ones first.
INPUT-SCHEMA is the `inputSchema' of a tool: a plist carrying `:properties'
and `:required'.  An absent schema, or one without any property, returns the
empty list — a tool without arguments is a normal case, not an error."
  (let ((required (my-mcp-explorer--sequence-to-list
                   (plist-get input-schema :required))))
    (my-mcp-explorer--required-first
     (mapcar
      (lambda (property)
        (pcase-let* ((`(,key ,specification) property)
                     (name (my-mcp-explorer--property-name key)))
          (my-mcp-explorer--make-argument
           :name name
           :type (plist-get specification :type)
           :description (plist-get specification :description)
           :enum (my-mcp-explorer--sequence-to-list
                  (plist-get specification :enum))
           :default (plist-get specification :default)
           :required (member name required))))
      (seq-partition (plist-get input-schema :properties) 2)))))

(defun my-mcp-explorer-prompt-arguments (raw-arguments)
  "Normalize RAW-ARGUMENTS into a list of descriptors, the mandatory ones first.
RAW-ARGUMENTS is the `:arguments' array of a prompt.  The protocol announces
no type there: the descriptors produced carry a nil `:type'."
  (my-mcp-explorer--required-first
   (mapcar
    (lambda (argument)
      (my-mcp-explorer--make-argument
       :name (plist-get argument :name)
       :type nil
       :description (plist-get argument :description)
       :enum nil
       :default nil
       :required (my-mcp-explorer-truthy-p (plist-get argument :required))))
    (my-mcp-explorer--sequence-to-list raw-arguments))))

;; --- Signature formatting ---------------------------------------------------

(defun my-mcp-explorer-format-value (value)
  "Return VALUE in the readable form of a signature or of a prompt.
The booleans reuse the words of the input, so that a default reads back as
one would retype it.  The strings keep their quotes, the only way to see that
a default is the empty string."
  (cond ((eq value t) "yes")
        ((eq value my-mcp-explorer-false) "no")
        ((stringp value) (format "%S" value))
        ((numberp value) (number-to-string value))
        (t (condition-case _failure
               (json-encode value)
             (error (format "%S" value))))))

(defun my-mcp-explorer-argument-label (argument)
  "Return the parenthesized mention of ARGUMENT.
It chains the type, the obligation, then the default value when the schema
announces one.  The type is omitted when the protocol does not provide any,
as is the case for prompts."
  (let* ((type-label (my-mcp-explorer--type-label (plist-get argument :type)))
         (default (plist-get argument :default))
         (mentions (delq nil
                         (list type-label
                               (if (my-mcp-explorer-argument-required-p argument)
                                   "required"
                                 "optional")
                               (when default
                                 (format "default %s"
                                         (my-mcp-explorer-format-value default)))))))
    (format "(%s)" (string-join mentions ", "))))

(defun my-mcp-explorer--format-argument (argument)
  "Return the signature line of ARGUMENT."
  (let ((enum (plist-get argument :enum))
        (description (plist-get argument :description)))
    (concat (format "  %s %s"
                    (my-mcp-explorer-argument-name argument)
                    (my-mcp-explorer-argument-label argument))
            (when enum
              (format "\n      permitted values: %s"
                      (mapconcat (lambda (value) (format "%s" value)) enum ", ")))
            (when description
              (format "\n      %s" description)))))

(defun my-mcp-explorer-format-signature (name description arguments)
  "Return the signature text of NAME.
DESCRIPTION is its help text or nil, ARGUMENTS the list of its descriptors.
An empty list produces an explicit mention: an empty argument section would
not say whether the element takes none or whether the schema was not read."
  (concat name
          (when description (format "\n\n%s" description))
          "\n\n"
          (if (null arguments)
              "No argument."
            (concat "Arguments:\n"
                    (mapconcat #'my-mcp-explorer--format-argument
                               arguments "\n")))
          "\n"))

;; --- Locating the element under point ---------------------------------------

;; `mcp-hub-detail--render' (mcp-hub.el:464) only sets a usable text property
;; on resources (`resource-uri').  Tool and prompt lines carry nothing but the
;; `outline-2' face.  There is therefore no direct path to the object: we read
;; the name from the bullet, and the kind from the nearest section header.
;; This is the most likely breaking point should the upstream rendering be
;; reworked, hence these two named constants.

(defconst my-mcp-explorer--bullet-regexp "^[ \t]*•[ \t]+\\(.+?\\)\\(?: (\\|$\\)"
  "Pattern of a bullet line of the detail buffer, name in the first group.
The cut on \" (\" discards the URI the rendering appends to the resources.")

(defconst my-mcp-explorer--section-kinds
  '(("Tools" . tool)
    ("Prompts" . prompt))
  "Section headers of the detail buffer that carry an executable element.
The other sections — status, resources, templates, roots — carry none and
return nil.")

(defun my-mcp-explorer--heading-at-point-p ()
  "True when the current line is a section header."
  (eq (get-text-property (line-beginning-position) 'face) 'outline-1))

(defun my-mcp-explorer--section-heading ()
  "Return the text of the section header covering point, or nil."
  (save-excursion
    (beginning-of-line)
    (catch 'heading
      (while t
        (when (my-mcp-explorer--heading-at-point-p)
          (throw 'heading (buffer-substring-no-properties
                           (point) (line-end-position))))
        (when (bobp)
          (throw 'heading nil))
        (forward-line -1)))))

(defun my-mcp-explorer--section-kind ()
  "Return the kind of the elements of the section covering point, or nil."
  (when-let* ((heading (my-mcp-explorer--section-heading)))
    (cdr (seq-find (lambda (entry) (string-prefix-p (car entry) heading))
                   my-mcp-explorer--section-kinds))))

(defun my-mcp-explorer--bullet-name ()
  "Return the name carried by the bullet of the current line, or nil."
  (save-excursion
    (beginning-of-line)
    (when (looking-at my-mcp-explorer--bullet-regexp)
      (string-trim (match-string-no-properties 1)))))

(defun my-mcp-explorer-element-at-point ()
  "Return the executable element under point, or nil.
The value returned is a plist `(:kind KIND :name NAME)' where KIND is `tool'
or `prompt'."
  (when-let* ((kind (my-mcp-explorer--section-kind))
              (name (my-mcp-explorer--bullet-name)))
    (list :kind kind :name name)))

;; --- Resolving the server and the element -----------------------------------

(defun my-mcp-explorer--server-name ()
  "Return the name of the server described by the current buffer.
Signal when the buffer is not an MCP server detail."
  (or (get-text-property (point-min) 'mcp-server-name)
      (user-error "This buffer is not an MCP server detail")))

(defun my-mcp-explorer--connection (server-name)
  "Return the live connection to SERVER-NAME.
Signal when the server is no longer connected: acting on a dead connection
would produce a far less readable error later on."
  (or (and (boundp 'mcp-server-connections)
           (hash-table-p mcp-server-connections)
           (gethash server-name mcp-server-connections))
      (user-error "Server %s is not connected" server-name)))

(defun my-mcp-explorer--collection (connection kind)
  "Return the list of the elements of kind KIND exposed by CONNECTION."
  (my-mcp-explorer--sequence-to-list
   (pcase kind
     ('tool (mcp--tools connection))
     ('prompt (mcp--prompts connection)))))

(defun my-mcp-explorer--find-element (connection kind name)
  "Return the element of kind KIND named NAME exposed by CONNECTION.
Signal when the server no longer exposes it: the detail buffer may predate a
reload."
  (or (seq-find (lambda (element) (equal name (plist-get element :name)))
                (my-mcp-explorer--collection connection kind))
      (user-error "The server no longer exposes %s" name)))

(defun my-mcp-explorer--element-arguments (kind element)
  "Return the argument descriptors of ELEMENT of kind KIND."
  (pcase kind
    ('tool (my-mcp-explorer-tool-arguments (plist-get element :inputSchema)))
    ('prompt (my-mcp-explorer-prompt-arguments (plist-get element :arguments)))))

(defun my-mcp-explorer--resolve-at-point ()
  "Return `(KIND ELEMENT SERVER-NAME CONNECTION)' for the current point.
Signal when nothing executable is under point, when the server is not
connected, or when it no longer exposes the element."
  (let* ((located (or (my-mcp-explorer-element-at-point)
                      (user-error "No tool or prompt under point")))
         (kind (plist-get located :kind))
         (name (plist-get located :name))
         (server-name (my-mcp-explorer--server-name))
         (connection (my-mcp-explorer--connection server-name)))
    (list kind
          (my-mcp-explorer--find-element connection kind name)
          server-name
          connection)))

;; --- Output buffers ---------------------------------------------------------

(defun my-mcp-explorer--display (buffer-name content)
  "Display CONTENT in the buffer BUFFER-NAME, read-only.
The buffer is reused from one call to the next: stacking one view per call
would drown the useful buffer under its predecessors."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert content)
        (goto-char (point-min)))
      (special-mode))
    (display-buffer buffer)
    buffer))

;; --- Conversion of an input to the expected type ----------------------------

;; Each converter takes the descriptor and the string typed in, and reports
;; with `user-error' naming the offending argument.  Reporting here, before any
;; call, avoids sending the server a value it would reject anyway — and makes
;; the mistake readable instead of surfacing it as a protocol error.

(defconst my-mcp-explorer--integer-regexp "\\`[+-]?[0-9]+\\'"
  "Pattern of an acceptable decimal integer.")

(defconst my-mcp-explorer--number-regexp
  "\\`[+-]?\\(?:[0-9]+\\(?:\\.[0-9]*\\)?\\|\\.[0-9]+\\)\\(?:[eE][+-]?[0-9]+\\)?\\'"
  "Pattern of an acceptable decimal number, exponential notation included.")

(defun my-mcp-explorer--to-string (_argument raw)
  "Rendre RAW tel quel."
  raw)

(defun my-mcp-explorer--to-integer (argument raw)
  "Convert RAW into an integer for ARGUMENT, or signal."
  (unless (string-match-p my-mcp-explorer--integer-regexp raw)
    (user-error "Argument %s expects an integer, not %S"
                (my-mcp-explorer-argument-name argument) raw))
  (string-to-number raw))

(defun my-mcp-explorer--to-number (argument raw)
  "Convert RAW into a number for ARGUMENT, or signal."
  (unless (string-match-p my-mcp-explorer--number-regexp raw)
    (user-error "Argument %s expects a number, not %S"
                (my-mcp-explorer-argument-name argument) raw))
  (string-to-number raw))

(defun my-mcp-explorer--to-boolean (argument raw)
  "Convert RAW into a JSON boolean for ARGUMENT, or signal."
  (pcase (downcase (string-trim raw))
    ((or "yes" "y" "true" "t" "1") t)
    ((or "no" "n" "false" "nil" "0") my-mcp-explorer-false)
    (_ (user-error "Argument %s expects yes or no, not %S"
                   (my-mcp-explorer-argument-name argument) raw))))

(defun my-mcp-explorer--parse-json (argument raw)
  "Parse RAW as a JSON fragment for ARGUMENT, or signal.
The objects are returned as hash tables rather than as plists: a plist
cannot tell the empty object from null, and `{}' would go back out as
`null'."
  (condition-case _failure
      (json-parse-string raw
                         :object-type 'hash-table
                         :false-object my-mcp-explorer-false
                         :null-object nil)
    (error
     (user-error "Argument %s expects valid JSON, not %S"
                 (my-mcp-explorer-argument-name argument) raw))))

(defun my-mcp-explorer--to-array (argument raw)
  "Convert RAW into a JSON array for ARGUMENT, or signal."
  (let ((value (my-mcp-explorer--parse-json argument raw)))
    (unless (vectorp value)
      (user-error "Argument %s expects a JSON list, not %S"
                  (my-mcp-explorer-argument-name argument) raw))
    value))

(defun my-mcp-explorer--to-object (argument raw)
  "Convert RAW into a JSON object for ARGUMENT, or signal."
  (let ((value (my-mcp-explorer--parse-json argument raw)))
    (unless (hash-table-p value)
      (user-error "Argument %s expects a JSON object, not %S"
                  (my-mcp-explorer-argument-name argument) raw))
    value))

(defun my-mcp-explorer--permitted-values (argument)
  "Return the permitted values of ARGUMENT as strings, or nil.
An imposed value may be a number: it is compared and offered in its
displayed form, the converter of the type bringing it back afterwards."
  (mapcar (lambda (value) (format "%s" value))
          (plist-get argument :enum)))

(defun my-mcp-explorer-convert-argument (argument raw)
  "Convert the input RAW into the value expected by ARGUMENT.
Signal with `user-error' when RAW does not fit — a value outside the
permitted ones, or a shape incompatible with the declared type."
  (when-let* ((permitted (my-mcp-explorer--permitted-values argument)))
    (unless (member raw permitted)
      (user-error "Argument %s only accepts: %s"
                  (my-mcp-explorer-argument-name argument)
                  (string-join permitted ", "))))
  (funcall (plist-get (cdr (my-mcp-explorer--type-entry (plist-get argument :type)))
                      :convert)
           argument raw))

;; --- Payload assembly -------------------------------------------------------

(defun my-mcp-explorer--blank-p (answer)
  "True when ANSWER carries no value."
  (or (null answer) (string-empty-p (string-trim answer))))

(defun my-mcp-explorer--payload-entry (argument answer)
  "Return the key-value pair of ARGUMENT for ANSWER, or nil.
An empty answer on an optional argument returns nil: the argument is then
omitted, and not passed as an empty string — the absence of a value and the
empty value do not say the same thing to the server."
  (if (my-mcp-explorer--blank-p answer)
      (when (my-mcp-explorer-argument-required-p argument)
        (user-error "Argument %s is required"
                    (my-mcp-explorer-argument-name argument)))
    (list (intern (concat ":" (my-mcp-explorer-argument-name argument)))
          (my-mcp-explorer-convert-argument argument answer))))

(defun my-mcp-explorer-build-payload (arguments answers)
  "Assemble the payload from ARGUMENTS and the inputs ANSWERS.
Return a plist ready for the call, or nil when no argument is passed.
Signal with `user-error' from the very first invalid input, hence always
before a call goes out."
  (unless (= (length arguments) (length answers))
    (error "As many answers as arguments expected: %d against %d"
           (length answers) (length arguments)))
  (apply #'append
         (cl-mapcar #'my-mcp-explorer--payload-entry arguments answers)))

;; --- Input plan -------------------------------------------------------------

(defun my-mcp-explorer--argument-prompt (argument)
  "Return the minibuffer prompt of ARGUMENT."
  (format "%s %s: "
          (my-mcp-explorer-argument-name argument)
          (my-mcp-explorer-argument-label argument)))

(defun my-mcp-explorer-read-plan (argument)
  "Return the input plan of ARGUMENT.
The value returned is a plist `(:prompt :reader :collection)'.  This function
carries the whole decision; the interactive loop merely executes it, which
makes it testable without touching the minibuffer."
  (let ((collection (or (my-mcp-explorer--permitted-values argument)
                        (plist-get (cdr (my-mcp-explorer--type-entry
                                         (plist-get argument :type)))
                                   :answers))))
    (list :prompt (my-mcp-explorer--argument-prompt argument)
          :reader (if collection 'completing-read 'read-string)
          :collection (if (symbolp collection) (symbol-value collection) collection))))

(defun my-mcp-explorer--read-argument (argument)
  "Ask the value of ARGUMENT in the minibuffer, returned as a raw string.
Completion does not require a match: an optional argument must stay omissible
through an empty answer.  Validation belongs to the converter, which signals
before any call anyway."
  (let ((plan (my-mcp-explorer-read-plan argument)))
    (pcase (plist-get plan :reader)
      ('completing-read (completing-read (plist-get plan :prompt)
                                         (plist-get plan :collection)
                                         nil nil))
      (_ (read-string (plist-get plan :prompt))))))

;; --- Result formatting ------------------------------------------------------

(defconst my-mcp-explorer--raw-separator "--- Raw answer ---"
  "Title of the section carrying the complete JSON answer.")

(defun my-mcp-explorer--pretty-json (value)
  "Return VALUE as indented JSON.
Fall back on a readable Lisp representation when VALUE cannot be encoded: a
degraded view is better than a command that fails after a successful call."
  (condition-case _failure
      (with-temp-buffer
        (insert (json-encode value))
        (json-pretty-print-buffer)
        (buffer-string))
    (error (pp-to-string value))))

(defun my-mcp-explorer-result-buffer-name (server-name element-name)
  "Return the name of the result buffer of ELEMENT-NAME on SERVER-NAME."
  (format "*MCP %s: %s*" server-name element-name))

(defun my-mcp-explorer-format-result (response readable-text)
  "Return the text of the result view of RESPONSE.
READABLE-TEXT is the readable content already extracted — it differs between
a tool and a prompt, and this function does not have to know.  An answer
carrying `:isError' is announced as such: it is an answer from the server,
not a breakdown, and its content is precisely the useful message."
  (concat
   (when (my-mcp-explorer-truthy-p (plist-get response :isError))
     "The server answered an error.\n\n")
   (if (my-mcp-explorer--blank-p readable-text)
       "(no textual content)"
     readable-text)
   "\n\n" my-mcp-explorer--raw-separator "\n\n"
   (my-mcp-explorer--pretty-json response)
   "\n"))

;; --- Readable content of a prompt answer ------------------------------------

;; `prompts/get' does not return a single content like `tools/call' but a
;; sequence of messages, each carrying a role.  Displaying them flat would lose
;; who says what, which is precisely the useful information of a prompt.

(defun my-mcp-explorer--content-text (content)
  "Return the text carried by the block CONTENT.
A non-textual block is reported rather than omitted: the reader must know
that something is missing from the view."
  (if (equal (plist-get content :type) "text")
      (plist-get content :text)
    (format "(non-textual %s content)"
            (or (plist-get content :type) "unknown"))))

(defun my-mcp-explorer--message-text (message)
  "Return the text of the message MESSAGE, preceded by its role."
  (let ((content (plist-get message :content)))
    (format "[%s]\n%s"
            (or (plist-get message :role) "unknown")
            (mapconcat #'my-mcp-explorer--content-text
                       (if (vectorp content)
                           (my-mcp-explorer--sequence-to-list content)
                         (list content))
                       "\n"))))

(defun my-mcp-explorer-prompt-messages-text (response)
  "Return the readable content of RESPONSE.
RESPONSE is what the server answers to the `prompts/get' method: its messages
are concatenated in the order it returned them."
  (mapconcat #'my-mcp-explorer--message-text
             (my-mcp-explorer--sequence-to-list (plist-get response :messages))
             "\n\n"))

;; --- Command: signature -----------------------------------------------------

(defun my-mcp-explorer-show-signature-at-point ()
  "Display the signature of the tool or prompt under point.
Intended for the detail buffer of `mcp-hub', where it is bound to `s'."
  (interactive)
  (pcase-let ((`(,kind ,element ,server-name ,_connection)
               (my-mcp-explorer--resolve-at-point)))
    (my-mcp-explorer--display
     (format "*MCP signature %s: %s*" server-name (plist-get element :name))
     (my-mcp-explorer-format-signature
      (plist-get element :name)
      (plist-get element :description)
      (my-mcp-explorer--element-arguments kind element)))))

;; --- Command: execution -----------------------------------------------------

(defconst my-mcp-explorer--kind-table
  '((tool   :call mcp-async-call-tool   :read my-mcp-explorer--tool-text)
    (prompt :call mcp-async-get-prompt  :read my-mcp-explorer-prompt-messages-text))
  "Asynchronous call and text extractor, by element kind.
A third case would be added here alone, without touching the command.")

(defun my-mcp-explorer--tool-text (response)
  "Return the readable content of RESPONSE, the answer to `tools/call'."
  (mcp--parse-tool-call-result response))

(defun my-mcp-explorer--kind-entry (kind)
  "Return the entry of `my-mcp-explorer--kind-table' for KIND."
  (or (cdr (assq kind my-mcp-explorer--kind-table))
      (user-error "Nothing executable for %s" kind)))

(defun my-mcp-explorer--caller (kind)
  "Return the asynchronous call function for an element of kind KIND."
  (plist-get (my-mcp-explorer--kind-entry kind) :call))

(defun my-mcp-explorer--readable-text (kind response)
  "Extract the readable content of RESPONSE for an element of kind KIND."
  (funcall (plist-get (my-mcp-explorer--kind-entry kind) :read) response))

(defun my-mcp-explorer--on-response (kind buffer-name server-name element-name)
  "Return the success callback that fills BUFFER-NAME.
KIND, SERVER-NAME and ELEMENT-NAME serve the extraction and the messages."
  (lambda (response)
    (my-mcp-explorer--display
     buffer-name
     (my-mcp-explorer-format-result
      response (my-mcp-explorer--readable-text kind response)))
    (message "MCP %s: %s...done" server-name element-name)))

(defun my-mcp-explorer--on-failure (server-name element-name)
  "Return the failure callback for ELEMENT-NAME on SERVER-NAME.
A transport failure is reported as a readable message: letting the error
through would display a backtrace that teaches nothing."
  (lambda (code error-message)
    (message "MCP %s: %s failed — error %s: %s"
             server-name element-name code error-message)))

(defun my-mcp-explorer-execute-at-point ()
  "Execute the tool or prompt under point.
The arguments are asked one by one in the minibuffer according to the schema,
then assembled and validated; no call goes out if an input does not fit.  The
call itself is asynchronous: a slow tool does not freeze Emacs.

Intended for the detail buffer of `mcp-hub', where it is bound to `x'."
  (interactive)
  (pcase-let* ((`(,kind ,element ,server-name ,connection)
                (my-mcp-explorer--resolve-at-point))
               (element-name (plist-get element :name))
               (caller (my-mcp-explorer--caller kind))
               (arguments (my-mcp-explorer--element-arguments kind element))
               (answers (mapcar #'my-mcp-explorer--read-argument arguments))
               (payload (my-mcp-explorer-build-payload arguments answers))
               (buffer-name (my-mcp-explorer-result-buffer-name
                             server-name element-name)))
    (message "MCP %s: %s..." server-name element-name)

    (funcall caller connection element-name payload
             (my-mcp-explorer--on-response kind buffer-name
                                           server-name element-name)
             (my-mcp-explorer--on-failure server-name element-name))))

;; --- Bindings ---------------------------------------------------------------

;; The detail buffer already uses `n', `p', `RET' and `g', and inherits `q'
;; from `special-mode': `s' and `x' are free.  Waiting for `mcp-hub' to be
;; loaded is what lets this module load on its own, in batch mode, without the
;; package.
(with-eval-after-load 'mcp-hub
  (define-key mcp-hub-detail-mode-map (kbd "s")
              #'my-mcp-explorer-show-signature-at-point)
  (define-key mcp-hub-detail-mode-map (kbd "x")
              #'my-mcp-explorer-execute-at-point))

(provide 'conf-mcp-explorer)

;;; conf-mcp-explorer.el ends here
