;;; ob-antigravity.el --- Blocs org-babel executes par le CLI agy -*- lexical-binding: t -*-

;;; Commentary:

;; Permet d'ecrire un prompt dans un bloc org et de l'envoyer au CLI `agy'
;; (Google Antigravity) par `C-c C-c' :
;;
;;   #+begin_src antigravity :model gemini-3.1-pro-high
;;   Resume le role de ce depot.
;;   #+end_src
;;
;; Le corps du bloc est le prompt, la reponse devient le resultat du bloc.
;;
;; Meme fonctionnement que `ob-claude', a deux differences pres imposees par
;; le CLI :
;;
;; - le prompt voyage dans la ligne de commande, comme valeur de `--print', et
;;   non sur l'entree standard : `agy --print' exige sa valeur, et il ne lit
;;   stdin qu'en `--input-format stream-json', qui obligerait a suivre un flux
;;   NDJSON pour un seul aller-retour ;
;;
;; - la sortie est demandee en JSON, seule forme qui porte l'identifiant de
;;   conversation. `agy' attribue cet identifiant lui-meme, la ou le CLI de
;;   Claude accepte qu'on le lui impose : une session ne peut donc etre reprise
;;   qu'une fois un premier bloc abouti.
;;
;; L'appel est asynchrone par defaut : une reponse prend des dizaines de
;; secondes et Emacs est mono-thread, un appel synchrone gelerait l'editeur
;; pendant toute la duree. Le bloc recoit d'abord un jeton, remplace par la
;; reponse a la fin du processus. `:async no' rend l'appel bloquant, utile en
;; batch ou pour les tests.
;;
;; En-tetes reconnus, en plus de ceux d'org :
;;
;;   :model    identifiant de modele, tel que liste par `agy models'
;;   :effort   niveau de raisonnement (low, medium, high)
;;   :agent    agent a utiliser pour la session
;;   :mode     mode d'execution (accept-edits, plan)
;;   :project  identifiant ou nom du projet Antigravity
;;   :add-dir  repertoire supplementaire ajoute a l'espace de travail
;;   :session  nom d'une conversation suivie d'un bloc a l'autre
;;   :async    yes (defaut) ou no
;;   :dir      repertoire de travail du CLI, gere par org lui-meme

;;; Code:

(require 'ob)
(require 'org-id)
(require 'subr-x)

;; --- Reglages ---------------------------------------------------------------

(defgroup org-babel-antigravity nil
  "Execution de blocs org-babel par le CLI Antigravity."
  :group 'org-babel)

(defcustom org-babel-antigravity-command "agy"
  "Nom ou chemin de l'executable du CLI Antigravity."
  :type 'string
  :group 'org-babel-antigravity)

(defcustom org-babel-antigravity-base-arguments '("--output-format" "json")
  "Arguments passes a chaque appel, avant ceux deduits des en-tetes.
La sortie JSON n'est pas un confort d'analyse : c'est la seule qui porte
l'identifiant de conversation et un statut d'erreur exploitable."
  :type '(repeat string)
  :group 'org-babel-antigravity)

;; Un bloc sans reponse est une erreur visible ; un bloc qui modifie des
;; fichiers a l'insu de l'auteur ne l'est pas. Le resultat par defaut est donc
;; un tiroir — la reponse est du texte libre, souvent multiligne et en
;; markdown — et l'export n'evalue rien.
(defvar org-babel-default-header-args:antigravity
  '((:results . "drawer replace")
    (:exports . "both")
    (:eval . "never-export"))
  "En-tetes par defaut des blocs `antigravity'.")

;; Linux plafonne chaque argument a 128 Kio (MAX_ARG_STRLEN). Au-dela, l'appel
;; echoue sur un E2BIG que rien ne rattache au prompt : la limite est verifiee
;; ici pour que le message nomme la cause.
(defconst org-babel-antigravity--maximum-prompt-bytes 130000
  "Taille maximale du prompt, en octets, une fois porte par `--print'.")

;; --- Traduction des en-tetes en arguments -----------------------------------

(defconst org-babel-antigravity--argument-by-header
  '((:model . "--model")
    (:effort . "--effort")
    (:agent . "--agent")
    (:mode . "--mode")
    (:project . "--project")
    (:add-dir . "--add-dir"))
  "Correspondance entre en-tete de bloc et option du CLI.
Chaque en-tete present ajoute son option suivie de sa valeur.")

(defun org-babel-antigravity--header-value (header params)
  "Renvoyer la valeur de HEADER dans PARAMS, sous forme de chaine.
Renvoie nil si l'en-tete est absent ou vide. Org lit les valeurs d'en-tete
avec `org-babel-read', qui peut rendre un nombre ou un symbole : la valeur
est reformatee avant d'atterrir dans une ligne de commande."
  (let ((value (cdr (assq header params))))
    (when value
      (let ((text (string-trim (format "%s" value))))
        (unless (string-empty-p text)
          text)))))

;; --- Sessions ---------------------------------------------------------------

(defvar org-babel-antigravity--conversation-identifiers (make-hash-table :test #'equal)
  "Identifiant de conversation rendu par le CLI, pour chaque nom de session.
Tant qu'un nom n'y figure pas, sa session n'a pas encore de conversation :
le prochain bloc en ouvrira une, et c'est la reponse du CLI qui livrera
l'identifiant a memoriser.")

(defun org-babel-antigravity--session-name (params)
  "Renvoyer le nom de session declare dans PARAMS, ou nil.
Org donne la valeur \"none\" quand aucune session n'est demandee."
  (let ((session (org-babel-antigravity--header-value :session params)))
    (unless (member session '(nil "none"))
      session)))

(defun org-babel-antigravity--session-arguments (session-name)
  "Renvoyer les arguments reprenant la conversation de SESSION-NAME.
Renvoie nil tant qu'aucune conversation n'a ete ouverte pour ce nom."
  (when-let* ((identifier (gethash session-name
                                   org-babel-antigravity--conversation-identifiers)))
    (list "--conversation" identifier)))

(defun org-babel-antigravity--remember-conversation (session-name response)
  "Associer a SESSION-NAME l'identifiant de conversation porte par RESPONSE.
Sans nom de session, la conversation est volontairement oubliee : le bloc
suivant repart d'un contexte vide."
  (when session-name
    (let ((identifier (alist-get 'conversation_id response)))
      (when (and identifier (not (string-empty-p identifier)))
        (puthash session-name identifier
                 org-babel-antigravity--conversation-identifiers)))))

(defun org-babel-antigravity-reset-session (session-name)
  "Oublier la conversation associee a SESSION-NAME.
Le prochain bloc de cette session repart d'un contexte vide."
  (interactive (list (completing-read
                      "Session antigravity : "
                      (hash-table-keys org-babel-antigravity--conversation-identifiers)
                      nil t)))
  (remhash session-name org-babel-antigravity--conversation-identifiers)
  (message "Session antigravity %s reinitialisee" session-name))

;; --- Ligne de commande ------------------------------------------------------

(defun org-babel-antigravity--build-arguments (params)
  "Construire la liste d'arguments du CLI a partir de PARAMS.
Le prompt n'en fait pas partie : il est ajoute en dernier, ou le CLI exige
qu'il soit."
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
  "Renvoyer l'argument portant PROMPT.
La valeur est collee a l'option : `agy' prend sinon l'option suivante pour
le prompt et ignore le reste de la ligne."
  (format "--print=%s" prompt))

;; --- Lecture de la reponse --------------------------------------------------

(defun org-babel-antigravity--parse-response (output)
  "Analyser OUTPUT, la sortie standard du CLI, et renvoyer son alist.
Renvoie nil quand la sortie n'est pas du JSON : un CLI qui meurt avant sa
reponse ecrit du texte libre, qu'il vaut mieux montrer tel quel que masquer
derriere une erreur d'analyse."
  (condition-case nil
      (json-parse-string output
                         :object-type 'alist
                         :null-object nil
                         :false-object nil)
    (error nil)))

(defun org-babel-antigravity--successful-p (exit-code response)
  "Dire si un appel sorti en EXIT-CODE avec RESPONSE a abouti.
Le code de sortie ne suffit pas : le CLI decrit l'echec dans son champ
`status', et les deux doivent concorder pour qu'une reponse soit publiee."
  (and (equal exit-code 0)
       (or (null response)
           (equal (alist-get 'status response) "SUCCESS"))))

(defun org-babel-antigravity--response-text (response output)
  "Renvoyer le texte de RESPONSE, ou OUTPUT quand le JSON manque."
  (string-trim (or (and response (alist-get 'response response))
                   output)))

(defun org-babel-antigravity--failure-message (exit-code response error-output)
  "Composer le message d'echec d'un appel sorti en EXIT-CODE.
Le motif est cherche d'abord dans le champ `error' de RESPONSE, ou le CLI
l'ecrit ; ERROR-OUTPUT ne sert que lorsqu'il meurt avant d'avoir produit son
JSON."
  (let ((reason (string-trim (or (and response (alist-get 'error response))
                                 error-output
                                 ""))))
    (format "agy a echoue (code %s)%s"
            exit-code
            (if (string-empty-p reason)
                ""
              (concat " : " reason)))))

(defun org-babel-antigravity--interpret-output (exit-code output error-output session-name)
  "Interpreter la sortie d'un appel et renvoyer un plist.
Le plist porte `:successful' et `:text'. En cas de succes, SESSION-NAME —
s'il est non nil — retient l'identifiant de conversation rendu par le CLI,
pour que le bloc suivant de la meme session la reprenne.

EXIT-CODE, OUTPUT et ERROR-OUTPUT sont le code de sortie, la sortie standard
et la sortie d'erreur du processus."
  (let ((response (org-babel-antigravity--parse-response output)))
    (if (org-babel-antigravity--successful-p exit-code response)
        (progn
          (org-babel-antigravity--remember-conversation session-name response)
          (list :successful t
                :text (org-babel-antigravity--response-text response output)))
      (list :successful nil
            :text (org-babel-antigravity--failure-message
                   exit-code response error-output)))))

;; --- Corps du bloc ----------------------------------------------------------

(defun org-babel-expand-body:antigravity (body params)
  "Substituer les variables de PARAMS dans BODY.
Une variable declaree par `:var nom=valeur' remplace toutes les occurrences
de `{{nom}}'. Le double accolade est choisi parce qu'il n'apparait pas dans
du texte courant, la ou `$nom' se confondrait avec le contenu du prompt."
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
  "Dire si le bloc decrit par PARAMS doit s'executer en arriere-plan."
  (not (member (org-babel-antigravity--header-value :async params) '("no" "nil"))))

(defun org-babel-antigravity--check-command ()
  "Verifier que le CLI est joignable, ou signaler une erreur explicite."
  (unless (executable-find org-babel-antigravity-command)
    (user-error "Executable %s introuvable dans `exec-path'"
                org-babel-antigravity-command)))

(defun org-babel-antigravity--check-prompt-length (prompt)
  "Refuser PROMPT quand il depasse ce qu'un argument peut porter."
  (when (> (string-bytes prompt) org-babel-antigravity--maximum-prompt-bytes)
    (user-error "Prompt trop long pour agy : %d octets, maximum %d"
                (string-bytes prompt)
                org-babel-antigravity--maximum-prompt-bytes)))

(defun org-babel-antigravity--file-contents (path)
  "Renvoyer le contenu du fichier PATH."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun org-babel-antigravity--execute-synchronously (arguments session-name)
  "Appeler le CLI avec ARGUMENTS et renvoyer sa reponse.
SESSION-NAME, s'il est non nil, retient l'identifiant de conversation en cas
de succes. Bloque Emacs jusqu'a la fin de l'appel."
  (let ((error-file (make-temp-file "ob-antigravity-error")))
    (unwind-protect
        (with-temp-buffer
          ;; Entree standard vide : le CLI ne lit pas le prompt sur stdin, et
          ;; un tube ouvert le laisserait attendre.
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
  "Remplacer PLACEHOLDER par RESULT dans BUFFER, selon les `:results' de PARAMS.
Le jeton est cherche dans tout le buffer plutot que suivi par un marqueur :
l'auteur continue d'editer pendant l'appel, et le bloc a pu se deplacer."
  (if (not (buffer-live-p buffer))
      (message "Reponse de agy perdue : le buffer d'origine est ferme")
    (with-current-buffer buffer
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (if (not (search-forward placeholder nil t))
              (message "Jeton %s introuvable : reponse de agy ignoree" placeholder)
            (goto-char (match-beginning 0))
            (let ((case-fold-search t))
              (when (re-search-backward "^[ \t]*#\\+begin_src\\_>" nil t)
                (org-babel-insert-result result
                                         (cdr (assq :result-params params)))))))))))

(defun org-babel-antigravity--make-sentinel (context)
  "Construire la sentinelle du processus decrit par CONTEXT.
CONTEXT est un plist portant les buffers de sortie, le buffer org d'origine,
le jeton a remplacer, les parametres du bloc et le nom de session."
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
  "Lancer le CLI avec ARGUMENTS sans bloquer Emacs.
Renvoie le jeton insere comme resultat provisoire du bloc ; la sentinelle le
remplacera par la reponse. PARAMS sert a reinserer le resultat avec les
memes `:results', SESSION-NAME a retenir la conversation ouverte."
  (let* ((placeholder (format "antigravity-en-cours:%s" (org-id-uuid)))
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
                   ;; Un tube dedie pour stderr : sans lui les messages
                   ;; d'erreur se melangent a la reponse JSON dans le meme
                   ;; buffer et la rendent inanalysable. La sentinelle
                   ;; `ignore' evite la ligne "Process finished" que le
                   ;; traitement par defaut ecrirait dans le buffer.
                   :stderr (make-pipe-process :name "ob-antigravity-error"
                                              :buffer error-buffer
                                              :noquery t
                                              :sentinel #'ignore)
                   :sentinel nil)))
    (set-process-sentinel process (org-babel-antigravity--make-sentinel context))
    ;; Le prompt est deja dans la ligne de commande : fermer l'entree standard
    ;; evite que le CLI attende une saisie qui ne viendra pas.
    (process-send-eof process)
    placeholder))

;;;###autoload
(defun org-babel-execute:antigravity (body params)
  "Envoyer BODY comme prompt au CLI agy et renvoyer sa reponse.
PARAMS porte les en-tetes du bloc. Appele par `org-babel-execute-src-block'."
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
