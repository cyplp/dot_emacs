;;; test-mcp-explorer.el --- tests de l'explorateur MCP -*- lexical-binding: t -*-

;;; Commentary:

;; Lancer depuis la racine du depot :
;;
;;   emacs -Q --batch -l ert -l tests/test-mcp-explorer.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; Les tests n'exercent que la couche pure du module — normalisation des
;; schemas, conversion des saisies, assemblage de la charge utile, plan de
;; saisie, formatage — plus le reperage sous le point, teste dans un buffer
;; fabrique a la main.  Aucun test ne suppose un serveur MCP joignable, et
;; aucun ne substitue de fonction : la boucle de saisie et l'appel reseau sont
;; hors de portee par construction, c'est la contrepartie assumee.
;;
;; Les assertions de keymap exigent `mcp-hub', absent sous `emacs -Q' ou
;; `elpa' n'est pas dans le `load-path'.  Elles se sautent d'elles-memes quand
;; le paquet manque, pour que la suite reste verte sur une machine nue.

;;; Code:

(require 'ert)

(load (expand-file-name
       "../conf-mcp-explorer.el"
       (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

;;; Fixtures

(defconst my-mcp-explorer-test--search-schema
  '( :type "object"
     :properties ( :query (:type "string" :description "Le terme cherche")
                   :limit (:type "integer"))
     :required ["query"])
  "Schema d'un outil a un argument requis et un optionnel.")

(defconst my-mcp-explorer-test--optional-first-schema
  '( :type "object"
     :properties ( :limit (:type "integer")
                   :query (:type "string"))
     :required ["query"])
  "Schema declarant l'argument optionnel avant l'obligatoire.")

(defconst my-mcp-explorer-test--enum-schema
  '( :type "object"
     :properties (:format (:type "string" :enum ["json" "texte"]))
     :required [])
  "Schema d'un outil a valeurs imposees.")

(defun my-mcp-explorer-test--names (arguments)
  "Rendre la liste des noms d'ARGUMENTS."
  (mapcar #'my-mcp-explorer-argument-name arguments))

(defun my-mcp-explorer-test--named (arguments name)
  "Rendre le descripteur nomme NAME parmi ARGUMENTS."
  (seq-find (lambda (argument)
              (equal name (my-mcp-explorer-argument-name argument)))
            arguments))

;;; Normalisation d'un schema d'outil

(ert-deftest my-mcp-explorer-test-tool-schema-lists-every-argument ()
  "Le schema d'un outil rend un descripteur par propriete."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-test--names arguments) '("query" "limit")))))

(ert-deftest my-mcp-explorer-test-tool-schema-keeps-type-and-description ()
  "Le descripteur porte le type, la description et l'obligation."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))
         (query (my-mcp-explorer-test--named arguments "query"))
         (limit (my-mcp-explorer-test--named arguments "limit")))
    (should (equal query '( :name "query" :type "string"
                            :description "Le terme cherche"
                            :enum nil :default nil :required t)))
    (should (equal limit '( :name "limit" :type "integer"
                            :description nil :enum nil
                            :default nil :required nil)))))

(ert-deftest my-mcp-explorer-test-tool-schema-puts-required-first ()
  "Les arguments obligatoires precedent les optionnels."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--optional-first-schema)))
    (should (equal (my-mcp-explorer-test--names arguments) '("query" "limit")))))

(ert-deftest my-mcp-explorer-test-tool-schema-keeps-enum ()
  "Les valeurs imposees sont rendues en liste."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))
         (format-argument (my-mcp-explorer-test--named arguments "format")))
    (should (equal (plist-get format-argument :enum) '("json" "texte")))))

(ert-deftest my-mcp-explorer-test-tool-schema-without-properties-is-empty ()
  "Un schema absent ou sans propriete rend la liste vide, sans erreur."
  (should (equal (my-mcp-explorer-tool-arguments nil) '()))
  (should (equal (my-mcp-explorer-tool-arguments '(:type "object")) '())))

;;; Normalisation des arguments d'un prompt

(ert-deftest my-mcp-explorer-test-prompt-arguments-carry-no-type ()
  "Les arguments d'un prompt rendent la meme forme, sans type."
  (let* ((arguments (my-mcp-explorer-prompt-arguments
                     [(:name "texte" :description "A resumer" :required t)]))
         (texte (my-mcp-explorer-test--named arguments "texte")))
    (should (equal texte '( :name "texte" :type nil
                            :description "A resumer"
                            :enum nil :default nil :required t)))))

(ert-deftest my-mcp-explorer-test-prompt-arguments-read-json-false ()
  "Un `:required' a faux JSON rend un argument optionnel.
`:json-false' est non nil en Lisp : le tester naivement rendrait tout
argument de prompt obligatoire."
  (let* ((arguments (my-mcp-explorer-prompt-arguments
                     [(:name "ton" :required :json-false)]))
         (ton (my-mcp-explorer-test--named arguments "ton")))
    (should-not (my-mcp-explorer-argument-required-p ton))))

(ert-deftest my-mcp-explorer-test-prompt-arguments-put-required-first ()
  "Les arguments obligatoires d'un prompt precedent les optionnels."
  (let ((arguments (my-mcp-explorer-prompt-arguments
                    [(:name "ton" :required :json-false)
                     (:name "texte" :required t)])))
    (should (equal (my-mcp-explorer-test--names arguments) '("texte" "ton")))))

(ert-deftest my-mcp-explorer-test-prompt-without-arguments-is-empty ()
  "Un prompt sans argument rend la liste vide."
  (should (equal (my-mcp-explorer-prompt-arguments nil) '()))
  (should (equal (my-mcp-explorer-prompt-arguments []) '())))

;;; Formatage de la signature

(ert-deftest my-mcp-explorer-test-signature-shows-name-and-description ()
  "La signature nomme l'element et rappelle sa description."
  (let ((signature (my-mcp-explorer-format-signature
                    "search" "Recherche plein texte"
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))))
    (should (string-match-p "\\`search$" (car (split-string signature "\n"))))
    (should (string-match-p "Recherche plein texte" signature))))

(ert-deftest my-mcp-explorer-test-signature-labels-type-and-obligation ()
  "Chaque argument montre son type et son caractere requis ou optionnel."
  (let ((signature (my-mcp-explorer-format-signature
                    "search" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))))
    (should (string-match-p "query (texte, requis)" signature))
    (should (string-match-p "Le terme cherche" signature))
    (should (string-match-p "limit (entier, optionnel)" signature))))

(ert-deftest my-mcp-explorer-test-signature-lists-permitted-values ()
  "Un argument a valeurs imposees enumere ses valeurs."
  (let ((signature (my-mcp-explorer-format-signature
                    "export" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))))
    (should (string-match-p "valeurs permises : json, texte" signature))))

(ert-deftest my-mcp-explorer-test-signature-states-absence-of-arguments ()
  "Un element sans argument le dit, plutot que de montrer une section vide."
  (let ((signature (my-mcp-explorer-format-signature "ping" nil '())))
    (should (string-match-p "Aucun argument" signature))
    (should-not (string-match-p "Arguments :" signature))))

(ert-deftest my-mcp-explorer-test-signature-of-prompt-omits-type ()
  "La signature d'un prompt n'annonce aucun type."
  (let ((signature (my-mcp-explorer-format-signature
                    "resume" nil
                    (my-mcp-explorer-prompt-arguments
                     [(:name "texte" :required t)]))))
    (should (string-match-p "texte (requis)" signature))))

;;; Conversion d'une saisie vers le type attendu

(defun my-mcp-explorer-test--argument (type &rest overrides)
  "Fabriquer un descripteur d'argument de type TYPE.
OVERRIDES ecrase les champs par defaut."
  (apply #'my-mcp-explorer--make-argument
         :name "champ" :type type :required t overrides))

(ert-deftest my-mcp-explorer-test-converts-text-verbatim ()
  "Un texte est transmis tel quel, y compris sans type declare."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "string") "emacs")
                 "emacs"))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument nil) "emacs")
                 "emacs")))

(ert-deftest my-mcp-explorer-test-converts-integer ()
  "Un entier est transmis comme nombre."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "integer") "10")
                 10))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "integer") "-3")
                 -3)))

(ert-deftest my-mcp-explorer-test-rejects-non-numeric-integer ()
  "Une reponse non numerique pour un entier est refusee."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "integer") "beaucoup")
                :type 'user-error)
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "integer") "1.5")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-number ()
  "Un decimal est transmis comme nombre, notation exponentielle comprise."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "number") "1.5")
                 1.5))
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "number") "2e3")
                 2000.0)))

(ert-deftest my-mcp-explorer-test-rejects-non-numeric-number ()
  "Une reponse non numerique pour un decimal est refusee."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "number") "beaucoup")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-boolean-to-json-value ()
  "Un booleen part en `t' ou `:json-false', jamais en chaine."
  (should (eq (my-mcp-explorer-convert-argument
               (my-mcp-explorer-test--argument "boolean") "oui")
              t))
  (should (eq (my-mcp-explorer-convert-argument
               (my-mcp-explorer-test--argument "boolean") "non")
              my-mcp-explorer-false))
  (should-not (stringp (my-mcp-explorer-convert-argument
                        (my-mcp-explorer-test--argument "boolean") "non"))))

(ert-deftest my-mcp-explorer-test-rejects-unreadable-boolean ()
  "Une reponse qui n'est ni oui ni non est refusee."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "boolean") "peut-etre")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-converts-json-array ()
  "Un fragment de liste JSON est analyse en vecteur."
  (should (equal (my-mcp-explorer-convert-argument
                  (my-mcp-explorer-test--argument "array") "[1, 2]")
                 [1 2])))

(ert-deftest my-mcp-explorer-test-converts-json-object ()
  "Un fragment d'objet JSON est analyse en table de hachage."
  (let ((value (my-mcp-explorer-convert-argument
                (my-mcp-explorer-test--argument "object") "{\"a\": 1}")))
    (should (hash-table-p value))
    (should (equal (gethash "a" value) 1))))

(ert-deftest my-mcp-explorer-test-keeps-empty-json-object-distinct ()
  "L'objet vide reste un objet, il ne devient pas nul."
  (let ((value (my-mcp-explorer-convert-argument
                (my-mcp-explorer-test--argument "object") "{}")))
    (should (hash-table-p value))
    (should (zerop (hash-table-count value)))))

(ert-deftest my-mcp-explorer-test-rejects-invalid-json ()
  "Un fragment JSON illisible est refuse."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "object") "{oups")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-rejects-json-of-wrong-shape ()
  "Une liste la ou un objet est attendu est refusee, et reciproquement."
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "object") "[1]")
                :type 'user-error)
  (should-error (my-mcp-explorer-convert-argument
                 (my-mcp-explorer-test--argument "array") "{}")
                :type 'user-error))

(ert-deftest my-mcp-explorer-test-rejects-value-outside-enum ()
  "Une valeur hors des valeurs permises est refusee."
  (let ((argument (my-mcp-explorer-test--argument
                   "string" :enum '("json" "texte"))))
    (should (equal (my-mcp-explorer-convert-argument argument "json") "json"))
    (should-error (my-mcp-explorer-convert-argument argument "yaml")
                  :type 'user-error)))

;;; Assemblage de la charge utile

(ert-deftest my-mcp-explorer-test-payload-carries-converted-values ()
  "La charge utile porte les valeurs converties, dans l'ordre des arguments."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" "10"))
                   '(:query "emacs" :limit 10)))))

(ert-deftest my-mcp-explorer-test-payload-omits-blank-optional ()
  "Un argument optionnel laisse vide ne figure pas dans la charge utile."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" ""))
                   '(:query "emacs")))
    (should (equal (my-mcp-explorer-build-payload arguments '("emacs" "   "))
                   '(:query "emacs")))))

(ert-deftest my-mcp-explorer-test-payload-refuses-blank-required ()
  "Un argument obligatoire laisse vide interrompt avant tout appel."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should-error (my-mcp-explorer-build-payload arguments '("" "10"))
                  :type 'user-error)))

(ert-deftest my-mcp-explorer-test-payload-of-argumentless-tool-is-empty ()
  "Un outil sans argument produit une charge utile vide."
  (should (null (my-mcp-explorer-build-payload '() '()))))

(ert-deftest my-mcp-explorer-test-payload-guards-against-answer-mismatch ()
  "Un nombre de reponses different du nombre d'arguments est une erreur.
C'est une faute de programmation, pas une charge utile a tronquer en
silence."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--search-schema)))
    (should-error (my-mcp-explorer-build-payload arguments '("emacs")))))

;;; Plan de saisie

(ert-deftest my-mcp-explorer-test-read-plan-prompts-with-type-and-obligation ()
  "L'invite porte le nom, le type et le caractere requis ou optionnel."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--search-schema))
         (query (my-mcp-explorer-test--named arguments "query"))
         (limit (my-mcp-explorer-test--named arguments "limit")))
    (should (equal (plist-get (my-mcp-explorer-read-plan query) :prompt)
                   "query (texte, requis) : "))
    (should (equal (plist-get (my-mcp-explorer-read-plan limit) :prompt)
                   "limit (entier, optionnel) : "))))

(ert-deftest my-mcp-explorer-test-read-plan-completes-on-enum ()
  "Une valeur imposee se lit en completion sur ses seules valeurs."
  (let* ((arguments (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--enum-schema))
         (plan (my-mcp-explorer-read-plan
                (my-mcp-explorer-test--named arguments "format"))))
    (should (eq (plist-get plan :reader) 'completing-read))
    (should (equal (plist-get plan :collection) '("json" "texte")))))

(ert-deftest my-mcp-explorer-test-read-plan-completes-on-boolean ()
  "Un booleen se lit en completion sur oui et non."
  (let ((plan (my-mcp-explorer-read-plan
               (my-mcp-explorer-test--argument "boolean"))))
    (should (eq (plist-get plan :reader) 'completing-read))
    (should (equal (plist-get plan :collection) '("oui" "non")))))

(ert-deftest my-mcp-explorer-test-read-plan-reads-plain-text ()
  "Un argument sans contrainte se lit au minibuffer libre."
  (dolist (type '("string" "integer" "number" "array" "object" nil))
    (let ((plan (my-mcp-explorer-read-plan
                 (my-mcp-explorer-test--argument type))))
      (should (eq (plist-get plan :reader) 'read-string))
      (should (null (plist-get plan :collection))))))

(ert-deftest my-mcp-explorer-test-read-plan-offers-only-convertible-answers ()
  "Toute reponse proposee est acceptee par le convertisseur du type.
Invite et conversion sortant de la meme ligne du tableau des types, elles
ne doivent jamais diverger."
  (dolist (argument (list (my-mcp-explorer-test--argument "boolean")
                          (my-mcp-explorer-test--argument
                           "string" :enum '("json" "texte"))))
    (dolist (answer (plist-get (my-mcp-explorer-read-plan argument) :collection))
      (should (my-mcp-explorer-convert-argument argument answer)))))

;;; Formatage du resultat

(ert-deftest my-mcp-explorer-test-result-shows-text-then-raw-json ()
  "La vue montre le contenu lisible, puis la reponse integrale en JSON."
  (let ((view (my-mcp-explorer-format-result
               '(:content [(:type "text" :text "trois resultats")])
               "trois resultats")))
    (should (string-match-p "trois resultats" view))
    (should (string-match-p "Reponse brute" view))
    (should (< (string-match "trois resultats" view)
               (string-match "Reponse brute" view)))
    (should (string-match-p "\"content\"" view))))

(ert-deftest my-mcp-explorer-test-result-announces-server-error ()
  "Une reponse portant `:isError' est annoncee, contenu compris."
  (let ((view (my-mcp-explorer-format-result
               '(:isError t :content [(:type "text" :text "index absent")])
               "index absent")))
    (should (string-match-p "erreur" view))
    (should (string-match-p "index absent" view))))

(ert-deftest my-mcp-explorer-test-result-ignores-json-false-error-flag ()
  "Un `:isError' a faux JSON n'annonce aucune erreur."
  (let ((view (my-mcp-explorer-format-result
               '(:isError :json-false :content []) "rien")))
    (should-not (string-match-p "a repondu une erreur" view))))

(ert-deftest my-mcp-explorer-test-result-states-absence-of-text ()
  "Une reponse sans contenu textuel le dit plutot que de rester muette."
  (let ((view (my-mcp-explorer-format-result '(:content []) "")))
    (should (string-match-p "aucun contenu textuel" view))))

(ert-deftest my-mcp-explorer-test-result-buffer-name-is-stable ()
  "Rejouer le meme element vise le meme buffer, donc n'en empile pas un second."
  (should (equal (my-mcp-explorer-result-buffer-name "local" "search")
                 (my-mcp-explorer-result-buffer-name "local" "search")))
  (should-not (equal (my-mcp-explorer-result-buffer-name "local" "search")
                     (my-mcp-explorer-result-buffer-name "local" "ping"))))

;;; Contenu lisible d'une reponse de prompt

(defconst my-mcp-explorer-test--prompt-response
  '(:messages [( :role "user"
                 :content (:type "text" :text "Cadre le sujet"))
               ( :role "assistant"
                 :content (:type "text" :text "Donne la consigne"))])
  "Reponse a `prompts/get' portant deux messages.")

(ert-deftest my-mcp-explorer-test-prompt-text-keeps-message-order ()
  "Les messages apparaissent dans l'ordre rendu par le serveur."
  (let ((view (my-mcp-explorer-prompt-messages-text
               my-mcp-explorer-test--prompt-response)))
    (should (string-match-p "Cadre le sujet" view))
    (should (string-match-p "Donne la consigne" view))
    (should (< (string-match "Cadre le sujet" view)
               (string-match "Donne la consigne" view)))))

(ert-deftest my-mcp-explorer-test-prompt-text-names-each-role ()
  "Chaque message est attribue a son role."
  (let ((view (my-mcp-explorer-prompt-messages-text
               my-mcp-explorer-test--prompt-response)))
    (should (string-match-p "\\[user\\]" view))
    (should (string-match-p "\\[assistant\\]" view))))

(ert-deftest my-mcp-explorer-test-prompt-text-flags-non-textual-content ()
  "Un contenu non textuel est signale plutot qu'omis en silence."
  (let ((view (my-mcp-explorer-prompt-messages-text
               '(:messages [(:role "user" :content (:type "image" :data "..."))]))))
    (should (string-match-p "contenu image non textuel" view))))

(ert-deftest my-mcp-explorer-test-prompt-text-reads-content-arrays ()
  "Un message portant plusieurs blocs de contenu les rend tous."
  (let ((view (my-mcp-explorer-prompt-messages-text
               '(:messages [( :role "user"
                              :content [(:type "text" :text "un")
                                        (:type "text" :text "deux")])]))))
    (should (string-match-p "un" view))
    (should (string-match-p "deux" view))))

(ert-deftest my-mcp-explorer-test-prompt-without-messages-is-empty ()
  "Une reponse sans message rend une chaine vide, sans erreur."
  (should (equal (my-mcp-explorer-prompt-messages-text '(:messages [])) ""))
  (should (equal (my-mcp-explorer-prompt-messages-text nil) "")))

(ert-deftest my-mcp-explorer-test-prompt-result-view-shows-messages ()
  "La vue de resultat d'un prompt montre ses messages puis le JSON brut."
  (let ((view (my-mcp-explorer-format-result
               my-mcp-explorer-test--prompt-response
               (my-mcp-explorer-prompt-messages-text
                my-mcp-explorer-test--prompt-response))))
    (should (string-match-p "Cadre le sujet" view))
    (should (string-match-p "Reponse brute" view))
    (should (string-match-p "\"messages\"" view))))

;;; Routage par nature d'element

(ert-deftest my-mcp-explorer-test-routes-tool-and-prompt ()
  "Chaque nature d'element vise son appel asynchrone."
  (should (eq (my-mcp-explorer--caller 'tool) #'mcp-async-call-tool))
  (should (eq (my-mcp-explorer--caller 'prompt) #'mcp-async-get-prompt)))

(ert-deftest my-mcp-explorer-test-refuses-unknown-kind ()
  "Une nature inconnue est refusee par `user-error', pas par une erreur nue."
  (should-error (my-mcp-explorer--caller 'resource) :type 'user-error))

(ert-deftest my-mcp-explorer-test-reads-prompt-response-through-routing ()
  "Le routage rend bien le texte des messages pour un prompt."
  (should (string-match-p
           "Cadre le sujet"
           (my-mcp-explorer--readable-text
            'prompt my-mcp-explorer-test--prompt-response))))

;;; Vue de resultat et rapport d'echec

(ert-deftest my-mcp-explorer-test-display-reuses-its-buffer ()
  "Rejouer un element remplace le contenu au lieu d'empiler une vue."
  (let ((buffer-name "*MCP test: reutilisation*"))
    (unwind-protect
        (progn
          (my-mcp-explorer--display buffer-name "premier")
          (let ((before (length (buffer-list))))
            (my-mcp-explorer--display buffer-name "second")
            (should (= before (length (buffer-list)))))
          (with-current-buffer buffer-name
            (should (string-match-p "second" (buffer-string)))
            (should-not (string-match-p "premier" (buffer-string)))))
      (when (get-buffer buffer-name) (kill-buffer buffer-name)))))

(ert-deftest my-mcp-explorer-test-display-is-read-only ()
  "La vue s'ouvre en `special-mode', donc en lecture seule."
  (let ((buffer-name "*MCP test: lecture seule*"))
    (unwind-protect
        (progn
          (my-mcp-explorer--display buffer-name "contenu")
          (with-current-buffer buffer-name
            (should (eq major-mode 'special-mode))
            (should buffer-read-only)))
      (when (get-buffer buffer-name) (kill-buffer buffer-name)))))

(ert-deftest my-mcp-explorer-test-transport-failure-names-code-and-message ()
  "Un echec de transport est rapporte en message lisible, sans trace.
Le serveur de reference rend les outils inconnus en reponse applicative :
ce chemin ne se declenche que sur une vraie erreur JSON-RPC, d'ou une
verification sur le rappel lui-meme."
  (let ((inhibit-message t))
    (with-current-buffer (get-buffer-create "*Messages*")
      (let ((inhibit-read-only t))
        (erase-buffer))
      (funcall (my-mcp-explorer--on-failure "local" "search")
               -32601 "methode inconnue")
      (let ((log (buffer-string)))
        (should (string-match-p "-32601" log))
        (should (string-match-p "methode inconnue" log))
        (should (string-match-p "search" log))
        (should (string-match-p "local" log))))))

;;; Valeurs par defaut

(defconst my-mcp-explorer-test--defaults-schema
  '( :type "object"
     :properties ( :limit (:type "integer" :default 50)
                   :raw (:type "boolean" :default :json-false)
                   :verbeux (:type "boolean" :default t)
                   :prefixe (:type "string" :default "")
                   :start (:type "string" :default nil)
                   :ip (:type "string")))
  "Schema couvrant chaque forme de valeur par defaut, `null' compris.")

(defun my-mcp-explorer-test--defaults-argument (name)
  "Rendre le descripteur NAME du schema des valeurs par defaut."
  (my-mcp-explorer-test--named
   (my-mcp-explorer-tool-arguments my-mcp-explorer-test--defaults-schema)
   name))

(ert-deftest my-mcp-explorer-test-label-shows-numeric-default ()
  "Un defaut numerique apparait dans le libelle de l'argument."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "limit"))
                 "(entier, optionnel, defaut 50)")))

(ert-deftest my-mcp-explorer-test-label-shows-false-default ()
  "Un defaut faux est affiche, il n'est pas confondu avec une absence.
`:json-false' est non nil : c'est une valeur par defaut a part entiere."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "raw"))
                 "(booleen, optionnel, defaut non)"))
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "verbeux"))
                 "(booleen, optionnel, defaut oui)")))

(ert-deftest my-mcp-explorer-test-label-shows-empty-string-default ()
  "Un defaut chaine vide reste visible grace aux guillemets."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "prefixe"))
                 "(texte, optionnel, defaut \"\")")))

(ert-deftest my-mcp-explorer-test-label-hides-null-and-absent-default ()
  "Un defaut `null' ou absent n'ajoute aucune mention."
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "start"))
                 "(texte, optionnel)"))
  (should (equal (my-mcp-explorer-argument-label
                  (my-mcp-explorer-test--defaults-argument "ip"))
                 "(texte, optionnel)")))

(ert-deftest my-mcp-explorer-test-signature-shows-defaults ()
  "La signature porte les valeurs par defaut du schema."
  (let ((signature (my-mcp-explorer-format-signature
                    "alerts" nil
                    (my-mcp-explorer-tool-arguments
                     my-mcp-explorer-test--defaults-schema))))
    (should (string-match-p "limit (entier, optionnel, defaut 50)" signature))
    (should (string-match-p "raw (booleen, optionnel, defaut non)" signature))))

(ert-deftest my-mcp-explorer-test-prompt-shows-default ()
  "L'invite de saisie annonce aussi le defaut : elle dit ce qu'une reponse
vide produira."
  (should (equal (plist-get (my-mcp-explorer-read-plan
                             (my-mcp-explorer-test--defaults-argument "limit"))
                            :prompt)
                 "limit (entier, optionnel, defaut 50) : ")))

(ert-deftest my-mcp-explorer-test-default-is-never-sent ()
  "Afficher un defaut ne le transmet pas : un optionnel vide reste omis.
Le serveur applique son propre defaut, ce module ne le devine pas a sa
place."
  (let ((arguments (my-mcp-explorer-tool-arguments
                    my-mcp-explorer-test--defaults-schema)))
    (should (null (my-mcp-explorer-build-payload
                   arguments (make-list (length arguments) ""))))))

(ert-deftest my-mcp-explorer-test-format-value-encodes-structures ()
  "Un defaut structure est rendu en JSON compact, sur une seule ligne."
  (should (equal (my-mcp-explorer-format-value [1 2]) "[1,2]"))
  (should-not (string-match-p "\n" (my-mcp-explorer-format-value [1 2]))))

;;; Reperage de l'element sous le point

(defun my-mcp-explorer-test--detail-buffer ()
  "Fabriquer un buffer reproduisant la structure du rendu de `mcp-hub'.
Seules comptent les proprietes que le reperage lit : le nom du serveur en
`point-min', la face `outline-1' des entetes, les puces des elements."
  (let ((buffer (generate-new-buffer " *mcp-explorer-test-detail*")))
    (with-current-buffer buffer
      (insert (propertize "local\n" 'mcp-server-name "local"))
      (insert "-----\n\n")
      (insert (propertize "Status:\n" 'face 'outline-1))
      (insert "  Running: Yes\n\n")
      (insert (propertize "Tools (2):\n" 'face 'outline-1))
      (insert (propertize "  • search" 'face 'outline-2) "\n")
      (insert "    Recherche plein texte\n")
      (insert (propertize "  • ping" 'face 'outline-2) "\n\n")
      (insert (propertize "Resources (1):\n" 'face 'outline-1))
      (insert (propertize "  • Journal" 'face 'outline-2)
              " (" (propertize "file:///journal" 'face 'font-lock-string-face) ")\n\n")
      (insert (propertize "Prompts (1):\n" 'face 'outline-1))
      (insert (propertize "  • resume" 'face 'outline-2) "\n"))
    buffer))

(defmacro my-mcp-explorer-test--at-line (pattern &rest body)
  "Executer BODY dans le buffer de detail, point sur la ligne PATTERN."
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
  "Une puce de la section des outils rend un element de nature `tool'."
  (my-mcp-explorer-test--at-line "• search"
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind tool :name "search")))))

(ert-deftest my-mcp-explorer-test-locates-prompt-under-point ()
  "Une puce de la section des prompts rend un element de nature `prompt'."
  (my-mcp-explorer-test--at-line "• resume"
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind prompt :name "resume")))))

(ert-deftest my-mcp-explorer-test-ignores-resources ()
  "Une puce de ressource ne rend rien : elle n'est pas executable."
  (my-mcp-explorer-test--at-line "• Journal"
    (should-not (my-mcp-explorer-element-at-point))))

(ert-deftest my-mcp-explorer-test-ignores-lines-without-bullet ()
  "Une ligne sans puce ne rend rien, meme dans une section d'outils."
  (my-mcp-explorer-test--at-line "Recherche plein texte"
    (should-not (my-mcp-explorer-element-at-point)))
  (my-mcp-explorer-test--at-line "Running: Yes"
    (should-not (my-mcp-explorer-element-at-point))))

(ert-deftest my-mcp-explorer-test-locates-tool-from-mid-line ()
  "Le reperage ne depend pas de la colonne du point."
  (my-mcp-explorer-test--at-line "• search"
    (end-of-line)
    (should (equal (my-mcp-explorer-element-at-point)
                   '(:kind tool :name "search")))))

;;; Refus explicites

(ert-deftest my-mcp-explorer-test-refuses-outside-detail-buffer ()
  "Hors d'un buffer de detail, la signature est refusee par `user-error'."
  (with-temp-buffer
    (insert "  • search\n")
    (goto-char (point-min))
    (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error)))

(ert-deftest my-mcp-explorer-test-refuses-when-nothing-under-point ()
  "Sur une ligne sans element, la signature est refusee par `user-error'."
  (my-mcp-explorer-test--at-line "Running: Yes"
    (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error)))

(ert-deftest my-mcp-explorer-test-refuses-when-server-disconnected ()
  "Sur un serveur deconnecte, la signature est refusee en le nommant."
  (my-mcp-explorer-test--at-line "• search"
    (let ((mcp-server-connections (make-hash-table :test #'equal)))
      (should-error (my-mcp-explorer-show-signature-at-point) :type 'user-error))))

;;; Liaisons du buffer de detail

(defun my-mcp-explorer-test--load-mcp-hub ()
  "Charger `mcp-hub' depuis les paquets installes, ou rendre nil."
  (require 'package)
  (package-initialize)
  (require 'mcp-hub nil t))

(defmacro my-mcp-explorer-test--in-detail-mode (&rest body)
  "Executer BODY dans un buffer ou `mcp-hub-detail-mode' est actif.
L'activation est indispensable : `mcp.el' pose ses `define-key' dans le
corps de `define-derived-mode' (mcp-hub.el:456), si bien que la keymap
reste vide tant que le mode n'a pas tourne au moins une fois."
  (declare (indent 0))
  `(with-temp-buffer
     (mcp-hub-detail-mode)
     ,@body))

(ert-deftest my-mcp-explorer-test-binds-signature-without-stealing-keys ()
  "`s' ouvre la signature, et les touches d'origine restent intactes."
  (unless (my-mcp-explorer-test--load-mcp-hub)
    (ert-skip "mcp-hub absent de cet environnement"))
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
