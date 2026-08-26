;;; conf-org.el --- Org mode -*- lexical-binding: t -*-

;;; Commentary:

;; Notes, agenda, capture, roam et export.
;;
;; Org n'est plus installe depuis MELPA : Emacs 30 embarque la version 9.7,
;; suffisante pour tout ce qui suit.  Cohabiter avec une seconde copie d'Org
;; est la source classique de messages "org-element-at-point: wrong type
;; argument", quand une partie du code vient d'une version et le reste d'une
;; autre.

;;; Code:

(require 'org)

(setq org-directory "~/dev/log_cyp")

(defun my-org-root (target)
  "Renvoyer le chemin de TARGET dans `org-directory'."
  (expand-file-name target org-directory))

(setq org-default-notes-file (my-org-root "refile.org"))
(setq org-agenda-files (list org-directory))

;; Masque les marqueurs d'emphase ; org-appear les revele au passage du curseur.
(setq org-hide-emphasis-markers t)

(setq org-log-done t)

;; Duree en heures et minutes plutot qu'en jours.
(setq org-duration-format 'h:mm)

;; --- Capture ----------------------------------------------------------------

(setq org-capture-templates
      `(("a" "Activité" entry
         (file+olp+datetree ,(my-org-root "activities.org"))
         "* %?"
         :clock-in t :clock-resume t)
        ("t" "Todo" entry
         (file ,(my-org-root "todos.org"))
         "\n* TODO %?\n%U\n%a\n"
         :clock-in t :clock-resume t)
        ("T" "Todo sans lien vers le fichier" item
         (file ,(my-org-root "todos.org"))
         "\n* TODO %?\n%U\n"
         :clock-in t :clock-resume t)
        ("p" "Appel téléphonique" entry
         (file+olp+datetree ,(my-org-root "activities.org"))
         "\n* PHONE %? :PHONE:\n%U"
         :clock-in t :clock-resume t)
        ("R" "Lien vers une recette" entry
         (file ,(my-org-root "cookbook.org"))
         "%(org-chef-get-recipe-from-url)"
         :empty-lines 1)
        ("r" "Recette" entry
         (file ,(my-org-root "cookbook.org"))
         "* %^{Recipe title: }\n  :PROPERTIES:\n  :source-url:\n  :servings:\n  :prep-time:\n  :cook-time:\n  :ready-in:\n  :END:\n** Ingredients\n   %?\n** Instructions\n\n")))

;; Commandes nommees plutot que des lambdas anonymes : elles apparaissent dans
;; `M-x', dans l'aide des touches et peuvent etre re-liees ailleurs.
(defun my-org-capture-activity ()
  "Capturer une activité dans l'arborescence par date."
  (interactive)
  (org-capture nil "a"))

(defun my-org-capture-todo ()
  "Capturer une tâche avec un lien vers le contexte courant."
  (interactive)
  (org-capture nil "t"))

(defun my-org-capture-todo-without-link ()
  "Capturer une tâche sans lien vers le fichier courant."
  (interactive)
  (org-capture nil "T"))

(defun my-org-visit-activities ()
  "Ouvrir le fichier des activités."
  (interactive)
  (find-file (my-org-root "activities.org")))

(defun my-org-visit-todos ()
  "Ouvrir le fichier des tâches."
  (interactive)
  (find-file (my-org-root "todos.org")))

(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c l") #'org-store-link)
(global-set-key (kbd "C-c a") #'org-agenda)

(global-set-key [f6] #'my-org-capture-activity)
(global-set-key [f8] #'my-org-capture-todo-without-link)
(global-set-key (kbd "<C-f8>") #'my-org-capture-todo)
(global-set-key (kbd "<S-f6>") #'my-org-visit-activities)
(global-set-key (kbd "<S-f8>") #'my-org-visit-todos)

;; Capture rapide rattachee au depot git courant.
;; Attention : ce paquet occupe M-; (`comment-dwim') et M-d (`kill-word').
(use-package org-repo-todo
  :ensure t
  :bind (("M-;" . ort/capture-todo)
         ("M-'" . ort/capture-checkitem)
         ("M-d" . ort/goto-todos)))

;; --- Mots-cles et priorites -------------------------------------------------

(setq org-todo-keyword-faces
      '(("ARCHIVE"     . (:foreground "light green" :weight bold))
        ("DISPATCHED"  . (:foreground "light blue" :weight bold))
        ("LATER"       . (:foreground "pink" :weight bold))
        ("INPROGRESS"  . (:foreground "light green" :weight bold))))

(use-package org-fancy-priorities
  :ensure t
  :hook (org-mode . org-fancy-priorities-mode)
  :config
  (setq org-fancy-priorities-list '("☇" "↑" "↓"))
  ;; `:size' n'est pas un attribut de face et etait ignore ; l'attribut
  ;; correspondant est `:height'.
  (setq org-priority-faces
        '((?A :foreground "red"    :weight bold :height 1.1)
          (?B :foreground "orange" :weight bold :height 1.1)
          (?C :foreground "green"  :weight bold :height 1.1))))

;; --- Blocs de code ----------------------------------------------------------

(org-babel-do-load-languages
 'org-babel-load-languages
 '((sql . t)
   (python . t)
   (shell . t)
   (plantuml . t)
   (restclient . t)
   (rust . t)
   (dot . t)))

(use-package ob-restclient :ensure t :after org)
(use-package ob-rust :ensure t :after org)

(setq org-src-fontify-natively t)

;; TAB dans un bloc src fait un aller-retour vers un buffer d'edition dans le
;; mode du langage. Au retour, Org reindentait tout le contenu de
;; `org-edit-src-content-indentation' colonnes (2 par defaut) : du code colle
;; a la marge partait definitivement vers la droite des le premier TAB.
;; Preserver l'indentation rend aussi le tangling fidele, ce qui compte pour
;; les langages ou l'indentation est semantique (python, yaml).
(setq org-src-preserve-indentation t)

(setq org-plantuml-jar-path "/usr/share/plantuml/plantuml.jar")

;; Rafraichit les images produites par un bloc apres son execution.
(defun my-org-redisplay-inline-images ()
  "Recharger les images en ligne si le buffer en affiche deja."
  (when org-inline-image-overlays
    (org-redisplay-inline-images)))

(add-hook 'org-babel-after-execute-hook #'my-org-redisplay-inline-images)

;; --- Export -----------------------------------------------------------------

(use-package ox-rst :ensure t :after org)
(use-package ox-pandoc :ensure t :after org)

(with-eval-after-load 'org
  (require 'ox-md nil t))

;; --- Apparence --------------------------------------------------------------

;; org-modern remplace org-bullets, qui faisait le meme travail : les deux
;; cumules doublaient les overlays de chaque buffer org.
(use-package org-modern
  :ensure t
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))

;; Garde le titre de la section courante visible en haut de la fenetre.
(use-package org-sticky-header
  :ensure t
  :hook (org-mode . org-sticky-header-mode))

;; Revele les marqueurs d'emphase du texte sous le curseur.
(use-package org-appear
  :vc (:url "https://github.com/awth13/org-appear" :rev :newest)
  :hook (org-mode . org-appear-mode))

;; Menu transient des commandes org.
(use-package org-menu
  :vc (:url "https://github.com/sheijk/org-menu" :rev :newest)
  :commands org-menu
  :bind (:map org-mode-map ("C-c m" . org-menu)))

;; Panneau lateral listant les taches et l'arborescence du fichier.
(use-package org-sidebar
  :vc (:url "https://github.com/alphapapa/org-sidebar" :rev :newest)
  :commands (org-sidebar-tree org-sidebar-toggle))

;; --- Presentation -----------------------------------------------------------

(defun my-org-present-start ()
  "Passer le buffer en mode presentation."
  (org-present-big)
  (org-display-inline-images)
  (org-present-hide-cursor)
  (org-present-read-only))

(defun my-org-present-stop ()
  "Revenir a l'edition normale apres une presentation."
  (org-present-small)
  (org-remove-inline-images)
  (org-present-show-cursor)
  (org-present-read-write))

(use-package org-present
  :ensure t
  :commands org-present
  :hook ((org-present-mode . my-org-present-start)
         (org-present-mode-quit . my-org-present-stop)))

;; --- Roam et journal --------------------------------------------------------

;; Commit automatique des fichiers de notes, active par une variable locale
;; posee dans les gabarits ci-dessous.
(use-package git-auto-commit-mode
  :ensure t
  :commands git-auto-commit-mode)

(setq org-roam-directory (my-org-root "roam"))
(make-directory org-roam-directory t)

(setq org-roam-v2-ack t)

(use-package org-roam
  :ensure t
  :custom
  (org-roam-directory (file-truename org-roam-directory))
  (org-roam-capture-templates
   '(("d" "default" plain "%?"
      :target (file+head
               "%<%Y-%m-%d--%H-%M-%S--${slug}.org>"
               "# -*- eval: (git-auto-commit-mode 1) -*-\n#+TITLE: ${title}\n* ${title}\n")
      :unnarrowed t)))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture))
  :config
  ;; `org-roam-mode' n'est pas un mode global : c'est le mode majeur du buffer
  ;; de backlinks. L'activer depuis `after-init', comme c'etait le cas, n'avait
  ;; pas d'effet utile. La synchronisation de la base se fait par
  ;; `org-roam-db-autosync-mode'.
  (org-roam-db-autosync-mode)
  (require 'org-roam-protocol))

(use-package org-journal
  :ensure t
  :bind ("C-c n j" . org-journal-new-entry)
  :custom
  (org-journal-date-prefix "# -*- eval: (git-auto-commit-mode 1) -*-\n#+TITLE: ")
  (org-journal-file-format "%Y-%m-%d.org")
  (org-journal-dir org-directory)
  ;; Ne pas reporter les TODO au jour suivant.
  (org-journal-carryover-items "")
  (org-journal-date-format "%A, %d %B %Y"))

;; Import de recettes depuis une URL, utilise par le gabarit de capture "R".
(use-package org-chef
  :ensure t
  :commands (org-chef-get-recipe-from-url org-chef-insert-recipe))

(provide 'conf-org)

;;; conf-org ends here
