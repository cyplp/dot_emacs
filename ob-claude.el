;;; ob-claude.el --- Blocs org-babel executes par le CLI claude -*- lexical-binding: t -*-

;;; Commentary:

;; Permet d'ecrire un prompt dans un bloc org et de l'envoyer au CLI `claude'
;; par `C-c C-c' :
;;
;;   #+begin_src claude :model sonnet
;;   Resume le role de ce depot.
;;   #+end_src
;;
;; Le corps du bloc est le prompt, la reponse devient le resultat du bloc.
;;
;; L'appel est asynchrone par defaut : une reponse prend des dizaines de
;; secondes et Emacs est mono-thread, un appel synchrone gelerait l'editeur
;; pendant toute la duree. Le bloc recoit d'abord un jeton, remplace par la
;; reponse a la fin du processus. `:async no' rend l'appel bloquant, utile en
;; batch ou pour les tests.
;;
;; Le prompt passe par l'entree standard et jamais par la ligne de commande :
;; un prompt long depasse la limite d'arguments du systeme, et un prompt
;; contenant des guillemets ou des retours a la ligne n'a pas a etre echappe.
;;
;; En-tetes reconnus, en plus de ceux d'org :
;;
;;   :model           alias ou nom complet du modele (sonnet, opus, ...)
;;   :effort          niveau d'effort (low, medium, high, xhigh, max)
;;   :agent           agent a utiliser pour la session
;;   :system          texte ajoute au prompt systeme
;;   :permission-mode plan, acceptEdits, bypassPermissions, ...
;;   :allowed-tools   liste d'outils autorises, separes par des espaces
;;   :add-dir         repertoires supplementaires accessibles
;;   :session         nom d'une conversation suivie d'un bloc a l'autre
;;   :async           yes (defaut) ou no
;;   :dir             repertoire de travail du CLI, gere par org lui-meme

;;; Code:

(require 'ob)
(require 'org-id)
(require 'subr-x)

;; --- Reglages ---------------------------------------------------------------

(defgroup org-babel-claude nil
  "Execution de blocs org-babel par le CLI claude."
  :group 'org-babel)

(defcustom org-babel-claude-command "claude"
  "Nom ou chemin de l'executable du CLI Claude Code."
  :type 'string
  :group 'org-babel-claude)

(defcustom org-babel-claude-base-arguments '("--print")
  "Arguments passes a chaque appel, avant ceux deduits des en-tetes.
`--print' est indispensable : sans lui le CLI ouvre une session interactive
plein ecran, qui n'a aucun sens derriere un tube."
  :type '(repeat string)
  :group 'org-babel-claude)

;; Un bloc sans reponse est une erreur visible ; un bloc qui modifie des
;; fichiers a l'insu de l'auteur ne l'est pas. Le resultat par defaut est donc
;; un tiroir — la reponse est du texte libre, souvent multiligne et en
;; markdown — et l'export n'evalue rien.
(defvar org-babel-default-header-args:claude
  '((:results . "drawer replace")
    (:exports . "both")
    (:eval . "never-export"))
  "En-tetes par defaut des blocs `claude'.")

;; --- Traduction des en-tetes en arguments -----------------------------------

(defconst org-babel-claude--argument-by-header
  '((:model . "--model")
    (:effort . "--effort")
    (:agent . "--agent")
    (:system . "--append-system-prompt")
    (:permission-mode . "--permission-mode")
    (:allowed-tools . "--allowed-tools")
    (:add-dir . "--add-dir"))
  "Correspondance entre en-tete de bloc et option du CLI.
Chaque en-tete present ajoute son option suivie de sa valeur.")

(defun org-babel-claude--header-value (header params)
  "Renvoyer la valeur de HEADER dans PARAMS, sous forme de chaine.
Renvoie nil si l'en-tete est absent ou vide. Org lit les valeurs d'en-tete
avec `org-babel-read', qui peut rendre un nombre ou un symbole : la valeur
est reformatee avant d'atterrir dans une ligne de commande."
  (let ((value (cdr (assq header params))))
    (when value
      (let ((text (string-trim (format "%s" value))))
        (unless (string-empty-p text)
          text)))))

(defun org-babel-claude--session-name (params)
  "Renvoyer le nom de session declare dans PARAMS, ou nil.
Org donne la valeur \"none\" quand aucune session n'est demandee."
  (let ((session (org-babel-claude--header-value :session params)))
    (unless (member session '(nil "none"))
      session)))

(defvar org-babel-claude--session-identifiers (make-hash-table :test #'equal)
  "Identifiant de conversation du CLI pour chaque nom de session.
Le premier bloc d'une session cree l'identifiant, les suivants reprennent la
meme conversation : le contexte des blocs precedents reste disponible.")

(defvar org-babel-claude--started-sessions (make-hash-table :test #'equal)
  "Sessions dont un bloc a deja ete execute avec succes.
Une conversation ne peut etre reprise qu'une fois creee : tant qu'aucun bloc
n'a abouti, l'identifiant doit etre cree et non repris.")

(defun org-babel-claude--session-arguments (session-name)
  "Renvoyer les arguments du CLI reprenant la conversation SESSION-NAME."
  (let ((identifier (or (gethash session-name org-babel-claude--session-identifiers)
                        (puthash session-name (org-id-uuid)
                                 org-babel-claude--session-identifiers))))
    (if (gethash session-name org-babel-claude--started-sessions)
        (list "--resume" identifier)
      (list "--session-id" identifier))))

(defun org-babel-claude-reset-session (session-name)
  "Oublier la conversation associee a SESSION-NAME.
Le prochain bloc de cette session repart d'un contexte vide."
  (interactive (list (completing-read
                      "Session claude : "
                      (hash-table-keys org-babel-claude--session-identifiers)
                      nil t)))
  (remhash session-name org-babel-claude--session-identifiers)
  (remhash session-name org-babel-claude--started-sessions)
  (message "Session claude %s reinitialisee" session-name))

(defun org-babel-claude--build-arguments (params)
  "Construire la liste d'arguments du CLI a partir de PARAMS."
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

;; --- Corps du bloc ----------------------------------------------------------

(defun org-babel-expand-body:claude (body params)
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

(defun org-babel-claude--async-p (params)
  "Dire si le bloc decrit par PARAMS doit s'executer en arriere-plan."
  (not (member (org-babel-claude--header-value :async params) '("no" "nil"))))

(defun org-babel-claude--check-command ()
  "Verifier que le CLI est joignable, ou signaler une erreur explicite."
  (unless (executable-find org-babel-claude-command)
    (user-error "Executable %s introuvable dans `exec-path'"
                org-babel-claude-command)))

(defun org-babel-claude--failure-message (exit-code error-output)
  "Composer le message d'echec d'un appel sorti en EXIT-CODE avec ERROR-OUTPUT."
  (format "claude a echoue (code %s)%s"
          exit-code
          (if (string-empty-p error-output)
              ""
            (concat " : " error-output))))

(defun org-babel-claude--execute-synchronously (prompt arguments session-name)
  "Appeler le CLI avec ARGUMENTS et PROMPT, et renvoyer sa reponse.
SESSION-NAME, s'il est non nil, est marque comme demarre en cas de succes.
Bloque Emacs jusqu'a la fin de l'appel."
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
  "Remplacer PLACEHOLDER par RESULT dans BUFFER, selon les `:results' de PARAMS.
Le jeton est cherche dans tout le buffer plutot que suivi par un marqueur :
l'auteur continue d'editer pendant l'appel, et le bloc a pu se deplacer."
  (if (not (buffer-live-p buffer))
      (message "Reponse de claude perdue : le buffer d'origine est ferme")
    (with-current-buffer buffer
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (if (not (search-forward placeholder nil t))
              (message "Jeton %s introuvable : reponse de claude ignoree" placeholder)
            (goto-char (match-beginning 0))
            (let ((case-fold-search t))
              (when (re-search-backward "^[ \t]*#\\+begin_src\\_>" nil t)
                (org-babel-insert-result result
                                         (cdr (assq :result-params params)))))))))))

(defun org-babel-claude--make-sentinel (context)
  "Construire la sentinelle du processus decrit par CONTEXT.
CONTEXT est un plist portant les buffers de sortie, le buffer org d'origine,
le jeton a remplacer, les parametres du bloc et le nom de session."
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
  "Lancer le CLI avec ARGUMENTS et PROMPT sans bloquer Emacs.
Renvoie le jeton insere comme resultat provisoire du bloc ; la sentinelle le
remplacera par la reponse. PARAMS sert a reinserer le resultat avec les
memes `:results', SESSION-NAME a marquer la conversation comme demarree."
  (let* ((placeholder (format "claude-en-cours:%s" (org-id-uuid)))
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
                   ;; Un tube dedie pour stderr : sans lui les messages
                   ;; d'erreur se melangent a la reponse dans le meme buffer.
                   ;; La sentinelle `ignore' evite la ligne "Process finished"
                   ;; que le traitement par defaut ecrirait dans le buffer.
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
  "Envoyer BODY comme prompt au CLI claude et renvoyer sa reponse.
PARAMS porte les en-tetes du bloc. Appele par `org-babel-execute-src-block'."
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
