;;; test-ob-antigravity.el --- tests des blocs org-babel antigravity -*- lexical-binding: t -*-

;;; Commentary:

;; Lancer depuis la racine du depot :
;;
;;   emacs -Q --batch -l ert -l tests/test-ob-antigravity.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; Aucun test n'appelle le vrai CLI : il coute du temps et de l'argent, et sa
;; reponse n'est pas deterministe. Un script bouchon prend sa place et rejoue
;; la forme exacte de la sortie de `agy' — une enveloppe JSON — ce qui suffit
;; a verifier ce qui est sous notre responsabilite : les arguments construits,
;; le prompt transmis, l'identifiant de conversation retenu, et l'endroit ou
;; la reponse atterrit.

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
  "Bouchon rendant le prompt recu dans l'enveloppe JSON du CLI.
Le prompt est lu dans le dernier argument, seul endroit ou `agy' l'accepte :
le test echoue si le prompt cesse d'y etre porte.")

(defconst my-ob-antigravity-test--error-stub
  "printf '{\"conversation_id\":\"\",\"status\":\"ERROR\",\"response\":\"\",\"error\":\"quota depasse\"}'
exit 1
"
  "Bouchon rejouant un echec annonce par le CLI : JSON sur stdout, code 1.")

(defun my-ob-antigravity-test--write-stub (script)
  "Ecrire SCRIPT dans un fichier executable et renvoyer son chemin."
  (let ((path (make-temp-file "ob-antigravity-stub" nil ".sh")))
    (with-temp-file path
      (insert "#!/bin/sh\n" script))
    (set-file-modes path #o755)
    path))

(defmacro my-ob-antigravity-test--with-stub (script &rest body)
  "Executer BODY avec le CLI remplace par un bouchon lancant SCRIPT."
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
  "Evaluer le premier bloc src de BLOCK et renvoyer le buffer org resultant."
  (let ((buffer (generate-new-buffer "*test-ob-antigravity*")))
    (with-current-buffer buffer
      (org-mode)
      (insert block)
      (goto-char (point-min))
      (search-forward "#+begin_src")
      (org-babel-execute-src-block))
    buffer))

(defun my-ob-antigravity-test--wait-for-result (buffer)
  "Attendre que le jeton provisoire de BUFFER soit remplace par la reponse."
  (let ((deadline (+ (float-time) 10)))
    (while (and (< (float-time) deadline)
                (with-current-buffer buffer
                  (save-excursion
                    (goto-char (point-min))
                    (search-forward "antigravity-en-cours:" nil t))))
      (accept-process-output nil 0.05))))

;;; Construction des arguments

(ert-deftest my-ob-antigravity-test-arguments-keep-json-output ()
  "La sortie JSON est toujours demandee : elle seule porte la conversation."
  (let ((arguments (org-babel-antigravity--build-arguments nil)))
    (should (equal (member "--output-format" arguments)
                   '("--output-format" "json")))))

(ert-deftest my-ob-antigravity-test-arguments-map-headers ()
  "Chaque en-tete reconnu devient une option suivie de sa valeur."
  (let ((arguments (org-babel-antigravity--build-arguments
                    '((:model . "gemini-3.1-pro-high")
                      (:effort . "high")
                      (:mode . "plan")))))
    (should (equal (member "--model" arguments)
                   '("--model" "gemini-3.1-pro-high" "--effort" "high"
                     "--mode" "plan")))))

(ert-deftest my-ob-antigravity-test-arguments-ignore-unknown-headers ()
  "Un en-tete hors correspondance n'atteint pas la ligne de commande."
  (should-not (member "--results"
                      (org-babel-antigravity--build-arguments
                       '((:results . "drawer"))))))

(ert-deftest my-ob-antigravity-test-prompt-is-attached-to-its-option ()
  "Le prompt est colle a `--print' : detache, le CLI l'ignore."
  (should (equal (org-babel-antigravity--prompt-argument "Bonjour")
                 "--print=Bonjour")))

;;; Sessions

(ert-deftest my-ob-antigravity-test-session-none-is-not-a-session ()
  "La valeur par defaut d'org pour `:session' ne reprend aucune conversation."
  (should-not (member "--conversation"
                      (org-babel-antigravity--build-arguments
                       '((:session . "none"))))))

(ert-deftest my-ob-antigravity-test-first-block-opens-the-conversation ()
  "Une session inconnue n'a pas d'identifiant a reprendre."
  (let ((org-babel-antigravity--conversation-identifiers
         (make-hash-table :test #'equal)))
    (should-not (member "--conversation"
                        (org-babel-antigravity--build-arguments
                         '((:session . "revue")))))))

(ert-deftest my-ob-antigravity-test-session-is-resumed-after-a-reply ()
  "L'identifiant rendu par le CLI est repris par le bloc suivant."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (org-babel-execute:antigravity "Bonjour" '((:async . "no")
                                               (:session . "revue")))
    (should (equal (member "--conversation"
                           (org-babel-antigravity--build-arguments
                            '((:session . "revue"))))
                   '("--conversation" "conv-1")))))

(ert-deftest my-ob-antigravity-test-conversation-is-not-kept-without-session ()
  "Sans `:session', un bloc n'ouvre aucune conversation suivie."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (org-babel-execute:antigravity "Bonjour" '((:async . "no")))
    (should (zerop (hash-table-count
                    org-babel-antigravity--conversation-identifiers)))))

(ert-deftest my-ob-antigravity-test-reset-session-forgets-the-conversation ()
  "Une session reinitialisee repart sans identifiant a reprendre."
  (let ((org-babel-antigravity--conversation-identifiers
         (make-hash-table :test #'equal)))
    (puthash "revue" "conv-1" org-babel-antigravity--conversation-identifiers)
    (org-babel-antigravity-reset-session "revue")
    (should-not (org-babel-antigravity--session-arguments "revue"))))

;;; Corps du bloc

(ert-deftest my-ob-antigravity-test-expand-body-substitutes-variables ()
  "Une variable de bloc remplace son marqueur dans le prompt."
  (should (equal (org-babel-expand-body:antigravity
                  "Traduis {{mot}} en anglais."
                  '((:var . (mot . "bonjour"))))
                 "Traduis bonjour en anglais.")))

(ert-deftest my-ob-antigravity-test-expand-body-leaves-plain-text ()
  "Un prompt sans marqueur traverse l'expansion intact."
  (should (equal (org-babel-expand-body:antigravity "Rien a substituer" nil)
                 "Rien a substituer")))

;;; Execution synchrone

(ert-deftest my-ob-antigravity-test-sync-returns-the-response-field ()
  "La reponse est extraite de l'enveloppe JSON, jamais rendue brute."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (should (equal (org-babel-execute:antigravity "Bonjour" '((:async . "no")))
                   "Bonjour"))))

(ert-deftest my-ob-antigravity-test-sync-reports-declared-failure ()
  "Un echec annonce par le CLI remonte avec son propre motif."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--error-stub
    (let ((failure (should-error (org-babel-execute:antigravity
                                  "Bonjour" '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 1" (cadr failure)))
      (should (string-match-p "quota depasse" (cadr failure))))))

(ert-deftest my-ob-antigravity-test-sync-reports-crash-without-json ()
  "Un CLI mort avant sa reponse remonte par sa sortie d'erreur."
  (my-ob-antigravity-test--with-stub "echo 'panique' >&2; exit 2"
    (let ((failure (should-error (org-babel-execute:antigravity
                                  "Bonjour" '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 2" (cadr failure)))
      (should (string-match-p "panique" (cadr failure))))))

(ert-deftest my-ob-antigravity-test-empty-block-is-rejected ()
  "Un bloc vide echoue avant tout appel au CLI."
  (should-error (org-babel-execute:antigravity "   \n" nil) :type 'user-error))

(ert-deftest my-ob-antigravity-test-oversized-prompt-is-rejected ()
  "Un prompt trop long pour un argument est refuse avec un motif nomme.
Sans ce garde-fou, l'appel echouerait sur un E2BIG que rien ne rattache au
prompt."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (let ((failure (should-error
                    (org-babel-execute:antigravity
                     (make-string (1+ org-babel-antigravity--maximum-prompt-bytes) ?x)
                     '((:async . "no")))
                    :type 'user-error)))
      (should (string-match-p "trop long" (cadr failure))))))

;;; Execution asynchrone

(ert-deftest my-ob-antigravity-test-async-inserts-answer-in-drawer ()
  "La reponse remplace le jeton provisoire dans le tiroir de resultats."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--echo-prompt-stub
    (let ((buffer (my-ob-antigravity-test--execute-block
                   "#+begin_src antigravity\nQuelle heure est-il\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-antigravity-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-search ":results:\nQuelle heure est-il\n:end:"
                                     (buffer-string)))))
        (kill-buffer buffer)))))

(ert-deftest my-ob-antigravity-test-async-reports-failure-in-buffer ()
  "Un echec du CLI est ecrit dans le resultat plutot que perdu."
  (my-ob-antigravity-test--with-stub my-ob-antigravity-test--error-stub
    (let ((buffer (my-ob-antigravity-test--execute-block
                   "#+begin_src antigravity\nReprends la session\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-antigravity-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-match-p "quota depasse" (buffer-string)))))
        (kill-buffer buffer)))))

(provide 'test-ob-antigravity)

;;; test-ob-antigravity.el ends here
