;;; test-org-emphasis.el --- tests de l'emphase org sur region -*- lexical-binding: t -*-

;;; Commentary:

;; Lancer depuis la racine du depot :
;;
;;   emacs -Q --batch -l ert -l tests/test-org-emphasis.el \
;;         -f ert-run-tests-batch-and-exit
;;
;; Les tests asserent le contenu du buffer, jamais son rendu : en batch ni
;; `org-appear-mode' ni `org-hide-emphasis-markers' n'entrent en jeu. La seule
;; assertion de mise en forme passe par l'analyseur d'org, qui lui est
;; deterministe.

;;; Code:

(require 'ert)
(require 'org)

(load (expand-file-name
       "../conf-org-emphasis.el"
       (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(define-derived-mode my-org-emphasis-test-derived-mode org-mode "TestOrg"
  "Mode derive d'org-mode, pour verifier l'heritage de `org-mode-map'.")

;;; Helpers

(defun my-org-emphasis-test--goto (target)
  "Placer le point juste apres TARGET.
TARGET est une chaine a chercher, ou nil pour la fin du buffer."
  (goto-char (point-min))
  (if target
      (search-forward target)
    (goto-char (point-max))))

(defun my-org-emphasis-test--type-on-selection (content selection marker &optional mode)
  "Selectionner SELECTION dans CONTENT puis frapper MARKER, en MODE.
Renvoie le texte du buffer resultant. MODE vaut `org-mode' par defaut."
  (with-temp-buffer
    (funcall (or mode #'org-mode))
    (insert content)
    (let ((end (my-org-emphasis-test--goto selection)))
      (set-mark (- end (length selection)))
      (goto-char end))

    (let ((last-command-event marker)
          (transient-mark-mode t))
      (call-interactively #'my-org-emphasize-region-or-self-insert))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun my-org-emphasis-test--type-without-selection (content target marker &optional command)
  "Placer le point apres TARGET dans CONTENT puis frapper MARKER.
COMMAND permet de rejouer la meme frappe avec une autre commande, afin de
comparer notre repli a la commande d'org qu'il delegue."
  (with-temp-buffer
    (org-mode)
    (insert content)
    (my-org-emphasis-test--goto target)
    (deactivate-mark)

    (let ((last-command-event marker))
      (call-interactively (or command #'my-org-emphasize-region-or-self-insert)))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun my-org-emphasis-test--bold-contents (content)
  "Renvoyer la liste des fragments qu'org analyse comme du gras dans CONTENT."
  (with-temp-buffer
    (org-mode)
    (insert content)
    (org-element-map (org-element-parse-buffer) 'bold
      (lambda (bold)
        (buffer-substring-no-properties
         (org-element-property :contents-begin bold)
         (org-element-property :contents-end bold))))))

;;; Slice 1 — encadrement de la region active et repli hors region

(ert-deftest my-org-emphasis-wraps-selection-with-typed-marker ()
  "Une selection simple est encadree par le marqueur frappe."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une longue phrase sans interet" "longue phrase" ?*))
        (expected "une *longue phrase* sans interet"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-wraps-selection-with-every-marker ()
  "Chacun des marqueurs d'`org-emphasis-alist' encadre avec lui-meme."
  (dolist (emphasis org-emphasis-alist)
    (let* ((marker (string-to-char (car emphasis)))
           (data (my-org-emphasis-test--type-on-selection
                  "une longue phrase sans interet" "longue phrase" marker))
           (expected (format "une %clongue phrase%c sans interet" marker marker)))
      (should (equal data expected)))))

(ert-deftest my-org-emphasis-leaves-non-marker-character-unbound ()
  "Le tiret n'est pas un marqueur org : il ne doit declencher aucun encadrement."
  (should-not (member "-" (mapcar #'car org-emphasis-alist)))
  (with-temp-buffer
    (org-mode)
    (should-not (eq (key-binding "-") #'my-org-emphasize-region-or-self-insert))))

(ert-deftest my-org-emphasis-without-selection-matches-org-self-insert ()
  "Sans region, la commande est indiscernable d'`org-self-insert-command'.
C'est ce qui garantit que le comportement d'org dans les tableaux — blanchiment
du champ, realignement — est preserve : il est delegue, jamais reimplemente."
  (let* ((table "| a | b |\n| c | d |\n")
         (data (my-org-emphasis-test--type-without-selection table "| a" ?=))
         (expected (my-org-emphasis-test--type-without-selection
                    table "| a" ?= #'org-self-insert-command)))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-without-selection-inserts-the-character ()
  "Sans region, le marqueur s'insere au point comme un caractere ordinaire."
  (let ((data (my-org-emphasis-test--type-without-selection "une phrase" nil ?*))
        (expected "une phrase*"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-keeps-single-emphasis-on-emphasized-selection ()
  "Une selection deja encadree, marqueurs compris, conserve une emphase unique."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une *longue phrase* sans interet" "*longue phrase*" ?*))
        (expected "une *longue phrase* sans interet"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-replaces-emphasis-instead-of-nesting ()
  "Frapper un autre marqueur remplace l'emphase au lieu de l'imbriquer."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une *longue phrase* sans interet" "*longue phrase*" ?/))
        (expected "une /longue phrase/ sans interet"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-applies-in-modes-derived-from-org ()
  "Un mode derive d'org-mode herite du comportement et des liaisons."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une longue phrase sans interet" "longue phrase" ?*
               #'my-org-emphasis-test-derived-mode))
        (expected "une *longue phrase* sans interet"))
    (should (equal data expected)))
  (with-temp-buffer
    (my-org-emphasis-test-derived-mode)
    (should (eq (key-binding "*") #'my-org-emphasize-region-or-self-insert))))

(ert-deftest my-org-emphasis-does-not-leak-outside-org ()
  "Hors d'un document org, les marqueurs restent des caracteres ordinaires."
  (dolist (emphasis org-emphasis-alist)
    (with-temp-buffer
      (fundamental-mode)
      (should-not (eq (key-binding (car emphasis))
                      #'my-org-emphasize-region-or-self-insert)))))

;;; Slice 2 — rognage des espaces en bord de selection

(ert-deftest my-org-emphasis-trims-trailing-whitespace ()
  "Un espace final dans la selection reste hors des marqueurs."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une longue phrase sans interet" "longue phrase " ?*))
        (expected "une *longue phrase* sans interet"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-trims-leading-whitespace ()
  "Un espace initial dans la selection reste hors des marqueurs."
  (let ((data (my-org-emphasis-test--type-on-selection
               "une longue phrase sans interet" " longue phrase" ?*))
        (expected "une *longue phrase* sans interet"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-trims-trailing-newline ()
  "Un saut de ligne en bord de selection est preserve hors des marqueurs."
  (let ((data (my-org-emphasis-test--type-on-selection
               "premiere ligne\nseconde ligne\n" "premiere ligne\n" ?=))
        (expected "=premiere ligne=\nseconde ligne\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-produces-emphasis-org-recognizes ()
  "Le rognage est ce qui fait qu'org analyse reellement le fragment en gras.
Sans lui, \"*longue phrase *\" resterait du texte brut : le geste echouerait
en silence, marqueurs visibles et aucune mise en forme."
  (let ((data (my-org-emphasis-test--bold-contents
               (my-org-emphasis-test--type-on-selection
                "une longue phrase sans interet" "longue phrase " ?*)))
        (expected '("longue phrase")))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-blank-selection ()
  "Une selection entierement blanche n'est pas encadree."
  (let ((data (my-org-emphasis-test--type-on-selection "une    phrase" "    " ?*))
        (expected "une    *phrase"))
    (should (equal data expected))))

;;; Slice 3 — inertie hors contexte de texte org

(ert-deftest my-org-emphasis-ignores-selection-in-source-block ()
  "Une selection dans un bloc de code n'est pas encadree."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_src python\nvalue = compute()\n#+end_src\n"
               "compute()" ?=))
        (expected "#+begin_src python\nvalue = compute()=\n#+end_src\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-selection-in-example-block ()
  "Une selection dans un bloc d'exemple n'est pas encadree."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_example\ntexte exemple\n#+end_example\n"
               "exemple" ?~))
        (expected "#+begin_example\ntexte exemple~\n#+end_example\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-ignores-selection-on-keyword-line ()
  "Une selection sur une ligne de mot-cle n'est pas encadree."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+TITLE: une longue phrase\n" "longue phrase" ?/))
        (expected "#+TITLE: une longue phrase/\n"))
    (should (equal data expected))))

(ert-deftest my-org-emphasis-still-applies-in-ordinary-paragraph ()
  "La detection de contexte ne doit pas desactiver la feature partout.
Sans ce cas positif, un predicat trop large passerait tous les autres tests
de la slice tout en rendant l'encadrement inoperant dans un document normal."
  (let ((data (my-org-emphasis-test--type-on-selection
               "#+begin_src python\nvalue = 1\n#+end_src\n\nune longue phrase sans interet\n"
               "longue phrase" ?*))
        (expected "#+begin_src python\nvalue = 1\n#+end_src\n\nune *longue phrase* sans interet\n"))
    (should (equal data expected))))

;;; test-org-emphasis.el ends here
