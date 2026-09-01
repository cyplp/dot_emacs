;;; conf-mcp-explorer.el --- Exploration executable des serveurs MCP -*- lexical-binding: t -*-

;;; Commentary:

;; Le buffer de detail de `mcp-hub' sait montrer ce qu'un serveur MCP expose —
;; outils, ressources, templates, prompts — et lire une ressource avec `RET'.
;; Il s'arrete la : rien n'y appelle un outil, et le schema d'arguments d'un
;; outil n'est jamais affiche.  On voit qu'un outil existe, jamais avec quoi
;; l'appeler.
;;
;; Ce module ajoute deux touches a ce buffer, sans en modifier le rendu :
;;
;;   s  signature de l'outil ou du prompt sous le point
;;   x  execution de cet outil ou de ce prompt
;;
;; Le module se scinde en deux couches, et cette separation est structurelle,
;; pas cosmetique : le depot proscrit les mocks, et aucun serveur MCP n'est
;; garanti joignable au moment des tests.  Seule une couche sans entree-sortie
;; est donc testable.
;;
;;   - Couche pure : normalisation d'un schema en descripteurs d'arguments,
;;     conversion d'une saisie vers le type attendu, assemblage de la charge
;;     utile, plan de saisie, formatage de la signature et du resultat.
;;   - Couche interactive : la boucle de lecture au minibuffer, l'appel reseau,
;;     l'affichage des buffers.  Elle ne decide de rien.
;;
;; Le cablage du serveur — adresse et jeton — reste entierement dans
;; `conf-mcp.el' et `secret.el'.  Ce module n'en connait rien.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)

;; Ces symboles appartiennent a `mcp.el' / `mcp-hub.el', charges a la demande.
;; On signale seulement leur existence au compilateur : le module doit rester
;; chargeable sans eux, c'est ce qui permet aux tests de tourner en batch.
(defvar mcp-server-connections)
(defvar mcp-hub-detail-mode-map)
(declare-function mcp--tools "mcp" (connection))
(declare-function mcp--prompts "mcp" (connection))
(declare-function mcp--parse-tool-call-result "mcp" (res))
(declare-function mcp-async-call-tool "mcp" (connection name arguments callback error-callback))
(declare-function mcp-async-get-prompt "mcp" (connection name arguments callback error-callback))

;; --- Types du protocole -----------------------------------------------------

;; `jsonrpc' decode le faux JSON en `:json-false' et le nul en nil
;; (jsonrpc.el:632).  Toute valeur booleenne construite ici doit donc etre `t'
;; ou `:json-false' pour se reserialiser correctement — surtout pas nil, qui
;; partirait en `null'.
(defconst my-mcp-explorer-false :json-false
  "Valeur Lisp que `jsonrpc' serialise en faux JSON.")

(defconst my-mcp-explorer--boolean-answers '("oui" "non")
  "Reponses proposees pour un argument booleen.
`y-or-n-p' serait plus direct mais ne sait pas rendre \"pas de reponse\" :
un booleen optionnel deviendrait impossible a omettre.  Passer par une
completion garde en outre le meme contrat pour tous les types — le
lecteur rend une chaine, le convertisseur en fait une valeur.")

(defconst my-mcp-explorer--type-table
  '(("string"  :label "texte"   :convert my-mcp-explorer--to-string)
    ("integer" :label "entier"  :convert my-mcp-explorer--to-integer)
    ("number"  :label "nombre"  :convert my-mcp-explorer--to-number)
    ("boolean" :label "booleen" :convert my-mcp-explorer--to-boolean
     :answers my-mcp-explorer--boolean-answers)
    ("array"   :label "liste"   :convert my-mcp-explorer--to-array)
    ("object"  :label "objet"   :convert my-mcp-explorer--to-object))
  "Decrire chaque type du schema JSON.
Chaque entree porte le libelle du type, son convertisseur et les reponses
proposees a la saisie.  Libelle, lecture et conversion sortent de la
meme ligne : les separer laisserait un jour proposer un choix que le
convertisseur refuse.  Un type absent ou inconnu retombe sur le texte —
les prompts n'annoncent aucun type, et un schema peut en declarer un que
ce module ignore.")

(defun my-mcp-explorer--type-entry (type)
  "Rendre l'entree de `my-mcp-explorer--type-table' pour TYPE.
Rend l'entree du texte quand TYPE est nil ou inconnu."
  (or (assoc type my-mcp-explorer--type-table)
      (assoc "string" my-mcp-explorer--type-table)))

(defun my-mcp-explorer--type-label (type)
  "Rendre le libelle lisible de TYPE, ou nil si TYPE est absent."
  (when type
    (plist-get (cdr (my-mcp-explorer--type-entry type)) :label)))

(defun my-mcp-explorer-truthy-p (value)
  "Vrai quand VALUE est vraie au sens JSON.
`:json-false' est une valeur non nil en Lisp : la tester avec `if' seul
rendrait tout booleen du protocole vrai."
  (and value (not (eq value my-mcp-explorer-false))))

;; --- Descripteurs d'arguments -----------------------------------------------

;; Les outils portent un `inputSchema' complet, les prompts un simple tableau
;; d'arguments sans type.  Les deux formes convergent ici vers un descripteur
;; unique, seule forme que connaisse le reste du module.

(cl-defun my-mcp-explorer--make-argument (&key name type description enum
                                               default required)
  "Construire le descripteur d'un argument.
NAME est son nom, TYPE son type du schema JSON ou nil, DESCRIPTION son
texte d'aide ou nil, ENUM la liste de ses seules valeurs permises ou nil,
DEFAULT la valeur retenue par le serveur en l'absence de saisie, REQUIRED
non nil quand l'argument est obligatoire.

DEFAULT nil couvre indistinctement la propriete absente et le `null' JSON
— les deux disent la meme chose ici : aucune valeur par defaut a montrer.
Un defaut faux arrive en revanche comme `:json-false', qui est non nil, et
reste donc affiche."
  (list :name name
        :type type
        :description description
        :enum enum
        :default default
        :required (and required t)))

(defun my-mcp-explorer-argument-name (argument)
  "Rendre le nom d'ARGUMENT."
  (plist-get argument :name))

(defun my-mcp-explorer-argument-required-p (argument)
  "Vrai quand ARGUMENT est obligatoire."
  (plist-get argument :required))

(defun my-mcp-explorer--sequence-to-list (value)
  "Rendre VALUE en liste, qu'elle soit vecteur, liste ou nil.
Le decodage JSON rend les tableaux sous forme de vecteurs."
  (append value nil))

(defun my-mcp-explorer--required-first (arguments)
  "Rendre ARGUMENTS reordonnes, obligatoires d'abord.
L'ordre d'origine est preserve a l'interieur de chaque groupe."
  (append (seq-filter #'my-mcp-explorer-argument-required-p arguments)
          (seq-remove #'my-mcp-explorer-argument-required-p arguments)))

(defun my-mcp-explorer--property-name (key)
  "Rendre le nom d'argument porte par KEY, mot-cle issu du decodage JSON."
  (substring (symbol-name key) 1))

(defun my-mcp-explorer-tool-arguments (input-schema)
  "Normaliser INPUT-SCHEMA en liste de descripteurs, obligatoires d'abord.
INPUT-SCHEMA est le `inputSchema' d'un outil : une plist portant
`:properties' et `:required'.  Un schema absent ou sans propriete rend la
liste vide — un outil sans argument est un cas normal, pas une erreur."
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
  "Normaliser RAW-ARGUMENTS en liste de descripteurs, obligatoires d'abord.
RAW-ARGUMENTS est le tableau `:arguments' d'un prompt.  Le protocole n'y
annonce aucun type : les descripteurs produits portent `:type' nil."
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

;; --- Formatage de la signature ----------------------------------------------

(defun my-mcp-explorer-format-value (value)
  "Rendre VALUE sous la forme lisible d'une signature ou d'une invite.
Les booleens reprennent les mots de la saisie, pour qu'un defaut se relise
tel qu'on le retaperait.  Les chaines gardent leurs guillemets, seule facon
de voir qu'un defaut est la chaine vide."
  (cond ((eq value t) "oui")
        ((eq value my-mcp-explorer-false) "non")
        ((stringp value) (format "%S" value))
        ((numberp value) (number-to-string value))
        (t (condition-case _failure
               (json-encode value)
             (error (format "%S" value))))))

(defun my-mcp-explorer-argument-label (argument)
  "Rendre la mention parenthesee d'ARGUMENT.
Elle enchaine le type, l'obligation, puis la valeur par defaut quand le
schema en annonce une.  Le type est omis quand le protocole n'en fournit
pas, cas des prompts."
  (let* ((type-label (my-mcp-explorer--type-label (plist-get argument :type)))
         (default (plist-get argument :default))
         (mentions (delq nil
                         (list type-label
                               (if (my-mcp-explorer-argument-required-p argument)
                                   "requis"
                                 "optionnel")
                               (when default
                                 (format "defaut %s"
                                         (my-mcp-explorer-format-value default)))))))
    (format "(%s)" (string-join mentions ", "))))

(defun my-mcp-explorer--format-argument (argument)
  "Rendre la ligne de signature d'ARGUMENT."
  (let ((enum (plist-get argument :enum))
        (description (plist-get argument :description)))
    (concat (format "  %s %s"
                    (my-mcp-explorer-argument-name argument)
                    (my-mcp-explorer-argument-label argument))
            (when enum
              (format "\n      valeurs permises : %s"
                      (mapconcat (lambda (value) (format "%s" value)) enum ", ")))
            (when description
              (format "\n      %s" description)))))

(defun my-mcp-explorer-format-signature (name description arguments)
  "Rendre le texte de signature de NAME.
DESCRIPTION est son texte d'aide ou nil, ARGUMENTS la liste de ses
descripteurs.  Une liste vide produit une mention explicite : une section
d'arguments vide ne dirait pas si l'element n'en prend aucun ou si le
schema n'a pas ete lu."
  (concat name
          (when description (format "\n\n%s" description))
          "\n\n"
          (if (null arguments)
              "Aucun argument."
            (concat "Arguments :\n"
                    (mapconcat #'my-mcp-explorer--format-argument
                               arguments "\n")))
          "\n"))

;; --- Reperage de l'element sous le point ------------------------------------

;; `mcp-hub-detail--render' (mcp-hub.el:464) ne pose de propriete textuelle
;; exploitable que sur les ressources (`resource-uri').  Les lignes d'outils et
;; de prompts ne portent que la face `outline-2'.  Il n'existe donc pas de voie
;; directe vers l'objet : on lit le nom sur la puce, et la nature dans l'entete
;; de section la plus proche.  C'est le point de rupture le plus probable a une
;; refonte du rendu amont, d'ou ces deux constantes nommees.

(defconst my-mcp-explorer--bullet-regexp "^[ \t]*•[ \t]+\\(.+?\\)\\(?: (\\|$\\)"
  "Motif d'une ligne de puce du buffer de detail, nom en premier groupe.
La coupure sur \" (\" ecarte l'URI que le rendu accole aux ressources.")

(defconst my-mcp-explorer--section-kinds
  '(("Tools" . tool)
    ("Prompts" . prompt))
  "Entetes de section du buffer de detail portant un element executable.
Les autres sections — statut, ressources, templates, roots — n'en portent
pas et rendent nil.")

(defun my-mcp-explorer--heading-at-point-p ()
  "Vrai quand la ligne courante est un entete de section."
  (eq (get-text-property (line-beginning-position) 'face) 'outline-1))

(defun my-mcp-explorer--section-heading ()
  "Rendre le texte de l'entete de section couvrant le point, ou nil."
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
  "Rendre la nature des elements de la section couvrant le point, ou nil."
  (when-let* ((heading (my-mcp-explorer--section-heading)))
    (cdr (seq-find (lambda (entry) (string-prefix-p (car entry) heading))
                   my-mcp-explorer--section-kinds))))

(defun my-mcp-explorer--bullet-name ()
  "Rendre le nom porte par la puce de la ligne courante, ou nil."
  (save-excursion
    (beginning-of-line)
    (when (looking-at my-mcp-explorer--bullet-regexp)
      (string-trim (match-string-no-properties 1)))))

(defun my-mcp-explorer-element-at-point ()
  "Rendre l'element executable sous le point, ou nil.
La valeur rendue est une plist `(:kind KIND :name NAME)' ou KIND vaut
`tool' ou `prompt'."
  (when-let* ((kind (my-mcp-explorer--section-kind))
              (name (my-mcp-explorer--bullet-name)))
    (list :kind kind :name name)))

;; --- Resolution du serveur et de l'element ----------------------------------

(defun my-mcp-explorer--server-name ()
  "Rendre le nom du serveur decrit par le buffer courant.
Signale quand le buffer n'est pas un detail de serveur MCP."
  (or (get-text-property (point-min) 'mcp-server-name)
      (user-error "Ce buffer n'est pas un detail de serveur MCP")))

(defun my-mcp-explorer--connection (server-name)
  "Rendre la connexion vivante vers SERVER-NAME.
Signale quand le serveur n'est plus connecte : agir sur une connexion
morte produirait une erreur bien moins lisible plus loin."
  (or (and (boundp 'mcp-server-connections)
           (hash-table-p mcp-server-connections)
           (gethash server-name mcp-server-connections))
      (user-error "Le serveur %s n'est pas connecte" server-name)))

(defun my-mcp-explorer--collection (connection kind)
  "Rendre la liste des elements de nature KIND exposes par CONNECTION."
  (my-mcp-explorer--sequence-to-list
   (pcase kind
     ('tool (mcp--tools connection))
     ('prompt (mcp--prompts connection)))))

(defun my-mcp-explorer--find-element (connection kind name)
  "Rendre l'element de nature KIND nomme NAME expose par CONNECTION.
Signale quand le serveur ne l'expose plus : le buffer de detail peut
dater d'avant un rechargement."
  (or (seq-find (lambda (element) (equal name (plist-get element :name)))
                (my-mcp-explorer--collection connection kind))
      (user-error "Le serveur n'expose plus %s" name)))

(defun my-mcp-explorer--element-arguments (kind element)
  "Rendre les descripteurs d'arguments d'ELEMENT de nature KIND."
  (pcase kind
    ('tool (my-mcp-explorer-tool-arguments (plist-get element :inputSchema)))
    ('prompt (my-mcp-explorer-prompt-arguments (plist-get element :arguments)))))

(defun my-mcp-explorer--resolve-at-point ()
  "Rendre `(KIND ELEMENT SERVER-NAME CONNECTION)' pour le point courant.
Signale quand rien d'executable n'est sous le point, quand le serveur
n'est pas connecte, ou quand il n'expose plus l'element."
  (let* ((located (or (my-mcp-explorer-element-at-point)
                      (user-error "Aucun outil ni prompt sous le point")))
         (kind (plist-get located :kind))
         (name (plist-get located :name))
         (server-name (my-mcp-explorer--server-name))
         (connection (my-mcp-explorer--connection server-name)))
    (list kind
          (my-mcp-explorer--find-element connection kind name)
          server-name
          connection)))

;; --- Buffers de sortie ------------------------------------------------------

(defun my-mcp-explorer--display (buffer-name content)
  "Afficher CONTENT dans le buffer BUFFER-NAME, en lecture seule.
Le buffer est reutilise d'un appel a l'autre : empiler une vue par appel
noierait le buffer utile sous ses predecesseurs."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert content)
        (goto-char (point-min)))
      (special-mode))
    (display-buffer buffer)
    buffer))

;; --- Conversion d'une saisie vers le type attendu ----------------------------

;; Chaque convertisseur prend le descripteur et la chaine saisie, et signale
;; par `user-error' en nommant l'argument fautif.  Signaler ici, avant tout
;; appel, evite d'envoyer au serveur une valeur qu'il rejettera de toute facon
;; — et rend la faute lisible au lieu de la faire remonter en erreur de
;; protocole.

(defconst my-mcp-explorer--integer-regexp "\\`[+-]?[0-9]+\\'"
  "Motif d'un entier decimal acceptable.")

(defconst my-mcp-explorer--number-regexp
  "\\`[+-]?\\(?:[0-9]+\\(?:\\.[0-9]*\\)?\\|\\.[0-9]+\\)\\(?:[eE][+-]?[0-9]+\\)?\\'"
  "Motif d'un nombre decimal acceptable, notation exponentielle comprise.")

(defun my-mcp-explorer--to-string (_argument raw)
  "Rendre RAW tel quel."
  raw)

(defun my-mcp-explorer--to-integer (argument raw)
  "Convertir RAW en entier pour ARGUMENT, ou signaler."
  (unless (string-match-p my-mcp-explorer--integer-regexp raw)
    (user-error "L'argument %s attend un entier, pas %S"
                (my-mcp-explorer-argument-name argument) raw))
  (string-to-number raw))

(defun my-mcp-explorer--to-number (argument raw)
  "Convertir RAW en nombre pour ARGUMENT, ou signaler."
  (unless (string-match-p my-mcp-explorer--number-regexp raw)
    (user-error "L'argument %s attend un nombre, pas %S"
                (my-mcp-explorer-argument-name argument) raw))
  (string-to-number raw))

(defun my-mcp-explorer--to-boolean (argument raw)
  "Convertir RAW en booleen JSON pour ARGUMENT, ou signaler."
  (pcase (downcase (string-trim raw))
    ((or "oui" "o" "true" "t" "yes" "y" "1") t)
    ((or "non" "n" "false" "nil" "0") my-mcp-explorer-false)
    (_ (user-error "L'argument %s attend oui ou non, pas %S"
                   (my-mcp-explorer-argument-name argument) raw))))

(defun my-mcp-explorer--parse-json (argument raw)
  "Analyser RAW comme fragment JSON pour ARGUMENT, ou signaler.
Les objets sont rendus en tables de hachage plutot qu'en plists : une
plist ne sait pas distinguer l'objet vide du nul, et `{}' repartirait en
`null'."
  (condition-case _failure
      (json-parse-string raw
                         :object-type 'hash-table
                         :false-object my-mcp-explorer-false
                         :null-object nil)
    (error
     (user-error "L'argument %s attend du JSON valide, pas %S"
                 (my-mcp-explorer-argument-name argument) raw))))

(defun my-mcp-explorer--to-array (argument raw)
  "Convertir RAW en tableau JSON pour ARGUMENT, ou signaler."
  (let ((value (my-mcp-explorer--parse-json argument raw)))
    (unless (vectorp value)
      (user-error "L'argument %s attend une liste JSON, pas %S"
                  (my-mcp-explorer-argument-name argument) raw))
    value))

(defun my-mcp-explorer--to-object (argument raw)
  "Convertir RAW en objet JSON pour ARGUMENT, ou signaler."
  (let ((value (my-mcp-explorer--parse-json argument raw)))
    (unless (hash-table-p value)
      (user-error "L'argument %s attend un objet JSON, pas %S"
                  (my-mcp-explorer-argument-name argument) raw))
    value))

(defun my-mcp-explorer--permitted-values (argument)
  "Rendre les valeurs permises d'ARGUMENT en chaines, ou nil.
Une valeur imposee peut etre un nombre : elle est comparee et proposee
sous sa forme affichee, le convertisseur du type la ramenant ensuite."
  (mapcar (lambda (value) (format "%s" value))
          (plist-get argument :enum)))

(defun my-mcp-explorer-convert-argument (argument raw)
  "Convertir la saisie RAW vers la valeur attendue par ARGUMENT.
Signale par `user-error' quand RAW ne convient pas — valeur hors des
valeurs permises, ou forme incompatible avec le type declare."
  (when-let* ((permitted (my-mcp-explorer--permitted-values argument)))
    (unless (member raw permitted)
      (user-error "L'argument %s n'accepte que : %s"
                  (my-mcp-explorer-argument-name argument)
                  (string-join permitted ", "))))
  (funcall (plist-get (cdr (my-mcp-explorer--type-entry (plist-get argument :type)))
                      :convert)
           argument raw))

;; --- Assemblage de la charge utile ------------------------------------------

(defun my-mcp-explorer--blank-p (answer)
  "Vrai quand ANSWER ne porte aucune valeur."
  (or (null answer) (string-empty-p (string-trim answer))))

(defun my-mcp-explorer--payload-entry (argument answer)
  "Rendre le couple cle-valeur d'ARGUMENT pour ANSWER, ou nil.
Une reponse vide sur un argument optionnel rend nil : l'argument est
alors omis, et non transmis comme chaine vide — l'absence de valeur et la
valeur vide ne disent pas la meme chose au serveur."
  (if (my-mcp-explorer--blank-p answer)
      (when (my-mcp-explorer-argument-required-p argument)
        (user-error "L'argument %s est requis"
                    (my-mcp-explorer-argument-name argument)))
    (list (intern (concat ":" (my-mcp-explorer-argument-name argument)))
          (my-mcp-explorer-convert-argument argument answer))))

(defun my-mcp-explorer-build-payload (arguments answers)
  "Assembler la charge utile depuis ARGUMENTS et les saisies ANSWERS.
Rend une plist prete pour l'appel, ou nil quand aucun argument n'est
transmis.  Signale par `user-error' des la premiere saisie invalide, donc
toujours avant qu'un appel ne parte."
  (unless (= (length arguments) (length answers))
    (error "Autant de reponses que d'arguments attendues : %d contre %d"
           (length answers) (length arguments)))
  (apply #'append
         (cl-mapcar #'my-mcp-explorer--payload-entry arguments answers)))

;; --- Plan de saisie ---------------------------------------------------------

(defun my-mcp-explorer--argument-prompt (argument)
  "Rendre l'invite de minibuffer d'ARGUMENT."
  (format "%s %s : "
          (my-mcp-explorer-argument-name argument)
          (my-mcp-explorer-argument-label argument)))

(defun my-mcp-explorer-read-plan (argument)
  "Rendre le plan de saisie d'ARGUMENT.
La valeur rendue est une plist `(:prompt :reader :collection)'.  Cette
fonction porte toute la decision ; la boucle interactive se contente de
l'executer, ce qui la rend testable sans toucher au minibuffer."
  (let ((collection (or (my-mcp-explorer--permitted-values argument)
                        (plist-get (cdr (my-mcp-explorer--type-entry
                                         (plist-get argument :type)))
                                   :answers))))
    (list :prompt (my-mcp-explorer--argument-prompt argument)
          :reader (if collection 'completing-read 'read-string)
          :collection (if (symbolp collection) (symbol-value collection) collection))))

(defun my-mcp-explorer--read-argument (argument)
  "Demander la valeur d'ARGUMENT au minibuffer, rendue en chaine brute.
La completion n'impose pas la correspondance : un argument optionnel doit
rester omissible par une reponse vide.  La validation revient au
convertisseur, qui signale de toute facon avant tout appel."
  (let ((plan (my-mcp-explorer-read-plan argument)))
    (pcase (plist-get plan :reader)
      ('completing-read (completing-read (plist-get plan :prompt)
                                         (plist-get plan :collection)
                                         nil nil))
      (_ (read-string (plist-get plan :prompt))))))

;; --- Formatage du resultat --------------------------------------------------

(defconst my-mcp-explorer--raw-separator "--- Reponse brute ---"
  "Titre de la section portant la reponse JSON integrale.")

(defun my-mcp-explorer--pretty-json (value)
  "Rendre VALUE en JSON indente.
Retombe sur une representation Lisp lisible quand VALUE ne se laisse pas
encoder : mieux vaut une vue degradee qu'une commande qui echoue apres un
appel reussi."
  (condition-case _failure
      (with-temp-buffer
        (insert (json-encode value))
        (json-pretty-print-buffer)
        (buffer-string))
    (error (pp-to-string value))))

(defun my-mcp-explorer-result-buffer-name (server-name element-name)
  "Rendre le nom du buffer de resultat de ELEMENT-NAME sur SERVER-NAME."
  (format "*MCP %s: %s*" server-name element-name))

(defun my-mcp-explorer-format-result (response readable-text)
  "Rendre le texte de la vue de resultat de RESPONSE.
READABLE-TEXT est le contenu lisible deja extrait — il differe entre un
outil et un prompt, et cette fonction n'a pas a le savoir.  Une reponse
portant `:isError' est annoncee comme telle : c'est une reponse du
serveur, pas une panne, et son contenu est justement le message utile."
  (concat
   (when (my-mcp-explorer-truthy-p (plist-get response :isError))
     "Le serveur a repondu une erreur.\n\n")
   (if (my-mcp-explorer--blank-p readable-text)
       "(aucun contenu textuel)"
     readable-text)
   "\n\n" my-mcp-explorer--raw-separator "\n\n"
   (my-mcp-explorer--pretty-json response)
   "\n"))

;; --- Contenu lisible d'une reponse de prompt --------------------------------

;; `prompts/get' ne rend pas un contenu unique comme `tools/call' mais une
;; suite de messages, chacun portant un role.  Les afficher a plat perdrait
;; qui dit quoi, ce qui est justement l'information utile d'un prompt.

(defun my-mcp-explorer--content-text (content)
  "Rendre le texte porte par le bloc CONTENT.
Un bloc non textuel est signale plutot qu'omis : le lecteur doit savoir
qu'il manque quelque chose a la vue."
  (if (equal (plist-get content :type) "text")
      (plist-get content :text)
    (format "(contenu %s non textuel)"
            (or (plist-get content :type) "inconnu"))))

(defun my-mcp-explorer--message-text (message)
  "Rendre le texte du message MESSAGE, precede de son role."
  (let ((content (plist-get message :content)))
    (format "[%s]\n%s"
            (or (plist-get message :role) "inconnu")
            (mapconcat #'my-mcp-explorer--content-text
                       (if (vectorp content)
                           (my-mcp-explorer--sequence-to-list content)
                         (list content))
                       "\n"))))

(defun my-mcp-explorer-prompt-messages-text (response)
  "Rendre le contenu lisible de RESPONSE.
RESPONSE est ce que le serveur repond a la methode `prompts/get' : ses
messages sont concatenes dans l'ordre ou il les a rendus."
  (mapconcat #'my-mcp-explorer--message-text
             (my-mcp-explorer--sequence-to-list (plist-get response :messages))
             "\n\n"))

;; --- Commande : signature ---------------------------------------------------

(defun my-mcp-explorer-show-signature-at-point ()
  "Afficher la signature de l'outil ou du prompt sous le point.
Destinee au buffer de detail de `mcp-hub', ou elle est liee a `s'."
  (interactive)
  (pcase-let ((`(,kind ,element ,server-name ,_connection)
               (my-mcp-explorer--resolve-at-point)))
    (my-mcp-explorer--display
     (format "*MCP signature %s: %s*" server-name (plist-get element :name))
     (my-mcp-explorer-format-signature
      (plist-get element :name)
      (plist-get element :description)
      (my-mcp-explorer--element-arguments kind element)))))

;; --- Commande : execution ---------------------------------------------------

(defconst my-mcp-explorer--kind-table
  '((tool   :call mcp-async-call-tool   :read my-mcp-explorer--tool-text)
    (prompt :call mcp-async-get-prompt  :read my-mcp-explorer-prompt-messages-text))
  "Appel asynchrone et extracteur de texte, par nature d'element.
Un troisieme cas s'ajouterait ici seul, sans toucher a la commande.")

(defun my-mcp-explorer--tool-text (response)
  "Rendre le contenu lisible de RESPONSE, reponse a `tools/call'."
  (mcp--parse-tool-call-result response))

(defun my-mcp-explorer--kind-entry (kind)
  "Rendre l'entree de `my-mcp-explorer--kind-table' pour KIND."
  (or (cdr (assq kind my-mcp-explorer--kind-table))
      (user-error "Rien d'executable pour %s" kind)))

(defun my-mcp-explorer--caller (kind)
  "Rendre la fonction d'appel asynchrone pour un element de nature KIND."
  (plist-get (my-mcp-explorer--kind-entry kind) :call))

(defun my-mcp-explorer--readable-text (kind response)
  "Extraire le contenu lisible de RESPONSE pour un element de nature KIND."
  (funcall (plist-get (my-mcp-explorer--kind-entry kind) :read) response))

(defun my-mcp-explorer--on-response (kind buffer-name server-name element-name)
  "Rendre le rappel de succes remplissant BUFFER-NAME.
KIND, SERVER-NAME et ELEMENT-NAME servent l'extraction et les messages."
  (lambda (response)
    (my-mcp-explorer--display
     buffer-name
     (my-mcp-explorer-format-result
      response (my-mcp-explorer--readable-text kind response)))
    (message "MCP %s : %s...fait" server-name element-name)))

(defun my-mcp-explorer--on-failure (server-name element-name)
  "Rendre le rappel d'echec pour ELEMENT-NAME sur SERVER-NAME.
Un echec de transport est rapporte en message lisible : laisser remonter
l'erreur afficherait une trace d'execution qui n'apprend rien."
  (lambda (code error-message)
    (message "MCP %s : echec de %s — erreur %s : %s"
             server-name element-name code error-message)))

(defun my-mcp-explorer-execute-at-point ()
  "Executer l'outil ou le prompt sous le point.
Les arguments sont demandes un par un au minibuffer d'apres le schema,
puis assembles et valides ; aucun appel ne part si une saisie ne convient
pas.  L'appel lui-meme est asynchrone : un outil lent ne gele pas Emacs.

Destinee au buffer de detail de `mcp-hub', ou elle est liee a `x'."
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
    (message "MCP %s : %s..." server-name element-name)
    (funcall caller connection element-name payload
             (my-mcp-explorer--on-response kind buffer-name
                                           server-name element-name)
             (my-mcp-explorer--on-failure server-name element-name))))

;; --- Liaisons ---------------------------------------------------------------

;; Le buffer de detail occupe deja `n', `p', `RET' et `g', et herite `q' de
;; `special-mode' : `s' et `x' sont libres.  L'attente du chargement de
;; `mcp-hub' est ce qui permet a ce module de se charger seul, en batch, sans
;; le paquet.
(with-eval-after-load 'mcp-hub
  (define-key mcp-hub-detail-mode-map (kbd "s")
              #'my-mcp-explorer-show-signature-at-point)
  (define-key mcp-hub-detail-mode-map (kbd "x")
              #'my-mcp-explorer-execute-at-point))

(provide 'conf-mcp-explorer)

;;; conf-mcp-explorer.el ends here
