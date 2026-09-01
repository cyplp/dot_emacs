;;; conf-antigravity.el --- Assistant Google Antigravity -*- lexical-binding: t -*-

;;; Commentary:

;; Integration du CLI `agy' (Google Antigravity) dans Emacs.
;;
;; L'integration ne va pas jusqu'a l'editeur, la ou celle de conf-claude.el
;; le fait : Antigravity ne parle que son propre protocole IDE, reserve a son
;; extension VS Code, et aucun paquet Emacs ne l'implemente. Pas de diff par
;; ediff, pas d'outils MCP cotes Emacs — mais une session par projet, une
;; fenetre laterale, l'envoi d'une reference au fichier courant et les blocs
;; org-babel de `ob-antigravity.el', ce qui couvre l'usage quotidien.
;;
;; Le terminal reste `eat', deja installe par conf-claude.el : le CLI est une
;; application plein ecran que `shell' ou `comint' ne savent pas afficher.

;;; Code:

(require 'project)

;; `eat' n'est chargee qu'au premier appel : sans ces declarations le
;; compilateur signale des symboles inconnus.
(declare-function eat-make "eat" (name program &optional startfile &rest switches))
(declare-function eat-term-send-string "eat" (terminal string))
(defvar eat-terminal)

;; --- Reglages ---------------------------------------------------------------

(defgroup antigravity nil
  "Assistant Google Antigravity dans un terminal Emacs."
  :group 'tools)

(defcustom antigravity-cli-path "agy"
  "Chemin de l'executable du CLI Antigravity.
Le repertoire ~/.local/bin ou il s'installe est deja ajoute a `exec-path'
par conf-claude.el."
  :type 'string
  :group 'antigravity)

(defcustom antigravity-window-width 0.4
  "Largeur de la fenetre de session, en fraction de la frame."
  :type 'number
  :group 'antigravity)

;; --- Session ----------------------------------------------------------------

(defun antigravity--project-directory ()
  "Retourner la racine du projet courant, a defaut `default-directory'."
  (if-let* ((current-project (project-current)))
      (project-root current-project)
    default-directory))

(defun antigravity--session-name ()
  "Retourner le nom de session associe au projet courant.
Une session par projet : deux depots ouverts simultanement ne doivent
partager ni conversation ni repertoire de travail."
  (format "agy: %s"
          (file-name-nondirectory
           (directory-file-name (antigravity--project-directory)))))

(defun antigravity--session-buffer ()
  "Retourner le tampon de la session du projet courant, ou nil.
`eat-make' entoure le nom d'asterisques ; on reconstruit la meme forme
plutot que de la memoriser dans une variable a tenir a jour."
  (get-buffer (concat "*" (antigravity--session-name) "*")))

(defun antigravity--display-session (session-buffer)
  "Afficher SESSION-BUFFER dans une fenetre laterale et la retourner.
Une fenetre laterale survit aux changements de disposition du reste du
cadre : la conversation ne disparait pas au premier `other-window'."
  (display-buffer session-buffer
                  `((display-buffer-in-side-window)
                    (side . right)
                    (window-width . ,antigravity-window-width))))

;;;###autoload
(defun antigravity-start ()
  "Demarrer la session Antigravity du projet courant, ou la rejoindre."
  (interactive)
  ;; conf-claude.el n'autoload `eat' que pour ses propres commandes : ici le
  ;; chargement est explicite, et differe jusqu'au premier appel.
  (require 'eat)
  ;; Le CLI herite du repertoire courant ; il doit demarrer a la racine pour
  ;; que son contexte couvre tout le depot et non le seul fichier ouvert.
  (let* ((default-directory (antigravity--project-directory))
         (session-buffer (eat-make (antigravity--session-name)
                                   antigravity-cli-path)))
    (select-window (antigravity--display-session session-buffer))))

;;;###autoload
(defun antigravity-toggle ()
  "Afficher ou masquer la fenetre de la session sans arreter le CLI."
  (interactive)
  (let* ((session-buffer (antigravity--session-buffer))
         (session-window (and session-buffer
                              (get-buffer-window session-buffer))))
    (cond
     ((null session-buffer) (antigravity-start))
     (session-window (delete-window session-window))
     (t (antigravity--display-session session-buffer)))))

;; --- Reference au code courant ----------------------------------------------

(defun antigravity--current-reference ()
  "Retourner une reference textuelle vers la region active ou la ligne courante.
Le chemin est relatif a la racine du projet, seule forme que le CLI resout
depuis son propre repertoire de travail.  Aucun prefixe `@' : dans le TUI ce
caractere ouvre un selecteur de fichiers qui avalerait le reste de la
chaine."
  (let* ((project-directory (antigravity--project-directory))
         (path (if buffer-file-name
                   (file-relative-name buffer-file-name project-directory)
                 (buffer-name)))
         (first-line (line-number-at-pos (if (use-region-p)
                                             (region-beginning)
                                           (point))))
         (last-line (line-number-at-pos (if (use-region-p)
                                            (region-end)
                                          (point)))))
    (if (= first-line last-line)
        (format "%s:%d" path first-line)
      (format "%s:%d-%d" path first-line last-line))))

;;;###autoload
(defun antigravity-insert-reference ()
  "Envoyer a la session une reference vers la region ou la ligne courante.
La reference est seulement inseree, sans validation : la question reste a
ecrire autour."
  (interactive)
  (let ((reference (antigravity--current-reference)))
    (unless (antigravity--session-buffer)
      (antigravity-start))
    (let ((session-buffer (antigravity--session-buffer)))
      (with-current-buffer session-buffer
        (eat-term-send-string eat-terminal (concat reference " ")))
      (select-window (antigravity--display-session session-buffer)))))

;; --- Raccourcis -------------------------------------------------------------

;; F5 et non F2 — pris par conf-claude.el — ni F3/F4, reserves aux macros
;; clavier, ni F7 a F10, repris par conf-python.el.  Meme repartition que pour
;; Claude : touche nue pour ouvrir, S- pour montrer/masquer, C- pour citer.
(global-set-key (kbd "<f5>") #'antigravity-start)
(global-set-key (kbd "<S-f5>") #'antigravity-toggle)
(global-set-key (kbd "<C-f5>") #'antigravity-insert-reference)

;; --- Blocs org --------------------------------------------------------------

;; `ob-antigravity' fait de `antigravity' un langage org-babel : le corps du
;; bloc est un prompt, `C-c C-c' l'envoie au CLI et la reponse devient le
;; resultat.
(with-eval-after-load 'org
  (require 'ob-antigravity)

  ;; Le prompt et la reponse sont du markdown : `org-edit-special' ouvre le
  ;; bloc dans markdown-mode plutot que dans `fundamental-mode'.
  (add-to-list 'org-src-lang-modes '("antigravity" . markdown))

  ;; `<ag' puis TAB insere le bloc.
  (add-to-list 'org-structure-template-alist '("ag" . "src antigravity")))

(provide 'conf-antigravity)

;;; conf-antigravity.el ends here
