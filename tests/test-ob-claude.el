;;; test-ob-claude.el --- tests des blocs org-babel claude -*- lexical-binding: t -*-

;;; Commentary:

;; Lancer depuis la racine du depot :
;;
;;   emacs -Q --batch -l ert -l tests/test-ob-claude.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; Aucun test n'appelle le vrai CLI : il coute du temps et de l'argent, et sa
;; reponse n'est pas deterministe. Un script bouchon prend sa place et se
;; contente de rendre ce qu'il a recu, ce qui suffit a verifier ce qui est
;; sous notre responsabilite : les arguments construits, le prompt transmis,
;; et l'endroit ou la reponse atterrit.

;;; Code:

(require 'ert)
(require 'org)

(add-to-list 'load-path
             (expand-file-name
              ".."
              (file-name-directory (or load-file-name buffer-file-name))))

(require 'ob-claude)

;;; Helpers

(defvar my-ob-claude-test--stub nil
  "Chemin du script bouchon qui remplace le CLI pendant les tests.")

(defun my-ob-claude-test--write-stub (script)
  "Ecrire SCRIPT dans un fichier executable et renvoyer son chemin."
  (let ((path (make-temp-file "ob-claude-stub" nil ".sh")))
    (with-temp-file path
      (insert "#!/bin/sh\n" script))
    (set-file-modes path #o755)
    path))

(defmacro my-ob-claude-test--with-stub (script &rest body)
  "Executer BODY avec le CLI remplace par un bouchon lancant SCRIPT."
  (declare (indent 1))
  `(let ((my-ob-claude-test--stub (my-ob-claude-test--write-stub ,script)))
     (unwind-protect
         (let ((org-babel-claude-command my-ob-claude-test--stub)
               (org-confirm-babel-evaluate nil))
           ,@body)
       (delete-file my-ob-claude-test--stub))))

(defun my-ob-claude-test--execute-block (block)
  "Evaluer le premier bloc src de BLOCK et renvoyer le buffer org resultant."
  (let ((buffer (generate-new-buffer "*test-ob-claude*")))
    (with-current-buffer buffer
      (org-mode)
      (insert block)
      (goto-char (point-min))
      (search-forward "#+begin_src")
      (org-babel-execute-src-block))
    buffer))

(defun my-ob-claude-test--wait-for-result (buffer)
  "Attendre que le jeton provisoire de BUFFER soit remplace par la reponse."
  (let ((deadline (+ (float-time) 10)))
    (while (and (< (float-time) deadline)
                (with-current-buffer buffer
                  (save-excursion
                    (goto-char (point-min))
                    (search-forward "claude-en-cours:" nil t))))
      (accept-process-output nil 0.05))))

;;; Construction des arguments

(ert-deftest my-ob-claude-test-arguments-keep-print ()
  "Le mode non interactif est toujours demande."
  (should (member "--print" (org-babel-claude--build-arguments nil))))

(ert-deftest my-ob-claude-test-arguments-map-headers ()
  "Chaque en-tete reconnu devient une option suivie de sa valeur."
  (let ((arguments (org-babel-claude--build-arguments
                    '((:model . "sonnet")
                      (:effort . "high")
                      (:system . "Reponds en francais")))))
    (should (equal (member "--model" arguments)
                   '("--model" "sonnet" "--effort" "high"
                     "--append-system-prompt" "Reponds en francais")))))

(ert-deftest my-ob-claude-test-arguments-ignore-unknown-headers ()
  "Un en-tete hors correspondance n'atteint pas la ligne de commande."
  (should-not (member "--results"
                      (org-babel-claude--build-arguments '((:results . "drawer"))))))

(ert-deftest my-ob-claude-test-session-none-is-not-a-session ()
  "La valeur par defaut d'org pour `:session' ne cree pas de conversation."
  (should-not (member "--session-id"
                      (org-babel-claude--build-arguments '((:session . "none"))))))

(ert-deftest my-ob-claude-test-session-is-created-then-resumed ()
  "Une session est creee au premier bloc, puis reprise par les suivants."
  (let ((org-babel-claude--session-identifiers (make-hash-table :test #'equal))
        (org-babel-claude--started-sessions (make-hash-table :test #'equal))
        (params '((:session . "revue"))))
    (let ((creation (org-babel-claude--build-arguments params)))
      (should (member "--session-id" creation))
      ;; La reprise n'a de sens qu'apres un appel abouti : c'est la sortie du
      ;; processus qui marque la session comme demarree.
      (puthash "revue" t org-babel-claude--started-sessions)
      (let ((resumption (org-babel-claude--build-arguments params)))
        (should (member "--resume" resumption))
        (should-not (member "--session-id" resumption))
        (should (equal (cadr (member "--resume" resumption))
                       (cadr (member "--session-id" creation))))))))

;;; Corps du bloc

(ert-deftest my-ob-claude-test-expand-body-substitutes-variables ()
  "Une variable de bloc remplace son marqueur dans le prompt."
  (should (equal (org-babel-expand-body:claude
                  "Traduis {{mot}} en anglais."
                  '((:var . (mot . "bonjour"))))
                 "Traduis bonjour en anglais.")))

(ert-deftest my-ob-claude-test-expand-body-leaves-plain-text ()
  "Un prompt sans marqueur traverse l'expansion intact."
  (should (equal (org-babel-expand-body:claude "Rien a substituer" nil)
                 "Rien a substituer")))

;;; Execution synchrone

(ert-deftest my-ob-claude-test-sync-sends-prompt-on-stdin ()
  "Le prompt est transmis par l'entree standard, pas par la ligne de commande."
  (my-ob-claude-test--with-stub "cat"
    (should (equal (org-babel-execute:claude "Bonjour" '((:async . "no")))
                   "Bonjour"))))

(ert-deftest my-ob-claude-test-sync-reports-failure ()
  "Un code de sortie non nul remonte avec le message d'erreur du CLI."
  (my-ob-claude-test--with-stub "echo 'quota depasse' >&2; exit 3"
    (let ((failure (should-error (org-babel-execute:claude "Bonjour"
                                                           '((:async . "no")))
                                 :type 'user-error)))
      (should (string-match-p "code 3" (cadr failure)))
      (should (string-match-p "quota depasse" (cadr failure))))))

(ert-deftest my-ob-claude-test-empty-block-is-rejected ()
  "Un bloc vide echoue avant tout appel au CLI."
  (should-error (org-babel-execute:claude "   \n" nil) :type 'user-error))

;;; Execution asynchrone

(ert-deftest my-ob-claude-test-async-inserts-answer-in-drawer ()
  "La reponse remplace le jeton provisoire dans le tiroir de resultats."
  (my-ob-claude-test--with-stub "cat"
    (let ((buffer (my-ob-claude-test--execute-block
                   "#+begin_src claude\nQuelle heure est-il ?\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-claude-test--wait-for-result buffer)
            (with-current-buffer buffer
              ;; `?' est un metacaractere : la comparaison porte sur la
              ;; chaine litterale, pas sur une expression reguliere.
              (should (string-search ":results:\nQuelle heure est-il ?\n:end:"
                                     (buffer-string)))))
        (kill-buffer buffer)))))

(ert-deftest my-ob-claude-test-async-reports-failure-in-buffer ()
  "Un echec du CLI est ecrit dans le resultat plutot que perdu."
  (my-ob-claude-test--with-stub "echo 'session inconnue' >&2; exit 1"
    (let ((buffer (my-ob-claude-test--execute-block
                   "#+begin_src claude\nReprends la session\n#+end_src\n")))
      (unwind-protect
          (progn
            (my-ob-claude-test--wait-for-result buffer)
            (with-current-buffer buffer
              (should (string-match-p "session inconnue" (buffer-string)))))
        (kill-buffer buffer)))))

(provide 'test-ob-claude)

;;; test-ob-claude.el ends here
