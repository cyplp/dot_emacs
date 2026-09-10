;;; conf-org.el --- Org mode -*- lexical-binding: t -*-

;;; Commentary:

;; Notes, agenda, capture, roam and export.
;;
;; Org is no longer installed from MELPA: Emacs 30 ships version 9.7, enough
;; for everything below.  Living side by side with a second copy of Org is the
;; classic source of "org-element-at-point: wrong type argument" messages, when
;; part of the code comes from one version and the rest from another.

;;; Code:

(require 'org)

(setq org-directory "~/dev/log_cyp")

(defun my-org-root (target)
  "Return the path of TARGET inside `org-directory'."
  (expand-file-name target org-directory))

(setq org-default-notes-file (my-org-root "refile.org"))
(setq org-agenda-files (list org-directory))

;; Hides the emphasis markers; org-appear reveals them under the cursor.
(setq org-hide-emphasis-markers t)

(setq org-log-done t)

;; Duration in hours and minutes rather than in days.
(setq org-duration-format 'h:mm)

;; --- Capture ----------------------------------------------------------------

(setq org-capture-templates
      `(("a" "Activity" entry
         (file+olp+datetree ,(my-org-root "activities.org"))
         "* %?"
         :clock-in t :clock-resume t)
        ("t" "Todo" entry
         (file ,(my-org-root "todos.org"))
         "\n* TODO %?\n%U\n%a\n"
         :clock-in t :clock-resume t)
        ("T" "Todo without a link to the file" item
         (file ,(my-org-root "todos.org"))
         "\n* TODO %?\n%U\n"
         :clock-in t :clock-resume t)
        ("p" "Phone call" entry
         (file+olp+datetree ,(my-org-root "activities.org"))
         "\n* PHONE %? :PHONE:\n%U"
         :clock-in t :clock-resume t)
        ("R" "Link to a recipe" entry
         (file ,(my-org-root "cookbook.org"))
         "%(org-chef-get-recipe-from-url)"
         :empty-lines 1)
        ("r" "Recipe" entry
         (file ,(my-org-root "cookbook.org"))
         "* %^{Recipe title: }\n  :PROPERTIES:\n  :source-url:\n  :servings:\n  :prep-time:\n  :cook-time:\n  :ready-in:\n  :END:\n** Ingredients\n   %?\n** Instructions\n\n")))

;; Named commands rather than anonymous lambdas: they show up in `M-x', in the
;; key help, and can be re-bound elsewhere.
(defun my-org-capture-activity ()
  "Capture an activity in the date tree."
  (interactive)
  (org-capture nil "a"))

(defun my-org-capture-todo ()
  "Capture a task with a link to the current context."
  (interactive)
  (org-capture nil "t"))

(defun my-org-capture-todo-without-link ()
  "Capture a task without a link to the current file."
  (interactive)
  (org-capture nil "T"))

(defun my-org-visit-activities ()
  "Open the activities file."
  (interactive)
  (find-file (my-org-root "activities.org")))

(defun my-org-visit-todos ()
  "Open the tasks file."
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

;; Quick capture attached to the current git repository.
;; Beware: this package takes over M-; (`comment-dwim') and M-d (`kill-word').
(use-package org-repo-todo
  :ensure t
  :bind (("M-;" . ort/capture-todo)
         ("M-'" . ort/capture-checkitem)
         ("M-d" . ort/goto-todos)))

;; --- Keywords and priorities ------------------------------------------------

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
  ;; `:size' is not a face attribute and was ignored; the matching attribute is
  ;; `:height'.
  (setq org-priority-faces
        '((?A :foreground "red"    :weight bold :height 1.1)
          (?B :foreground "orange" :weight bold :height 1.1)
          (?C :foreground "green"  :weight bold :height 1.1))))

;; --- Code blocks ------------------------------------------------------------

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

;; TAB in a src block makes a round trip to an editing buffer in the mode of
;; the language. On the way back, Org reindented the whole content by
;; `org-edit-src-content-indentation' columns (2 by default): code flush with
;; the margin drifted permanently to the right on the very first TAB.
;; Preserving the indentation also makes tangling faithful, which matters for
;; the languages where indentation is semantic (python, yaml).
(setq org-src-preserve-indentation t)

(setq org-plantuml-jar-path "/usr/share/plantuml/plantuml.jar")

;; Refreshes the images produced by a block after it runs.
(defun my-org-redisplay-inline-images ()
  "Reload the inline images if the buffer already displays some."
  (when org-inline-image-overlays
    (org-redisplay-inline-images)))

(add-hook 'org-babel-after-execute-hook #'my-org-redisplay-inline-images)

;; --- Export -----------------------------------------------------------------

(use-package ox-rst :ensure t :after org)
(use-package ox-pandoc :ensure t :after org)

(with-eval-after-load 'org
  (require 'ox-md nil t))

;; --- Appearance -------------------------------------------------------------

;; org-modern replaces org-bullets, which did the same job: the two together
;; doubled the overlays of every org buffer.
(use-package org-modern
  :ensure t
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))

;; Keeps the title of the current section visible at the top of the window.
(use-package org-sticky-header
  :ensure t
  :hook (org-mode . org-sticky-header-mode))

;; Reveals the emphasis markers of the text under the cursor.
(use-package org-appear
  :vc (:url "https://github.com/awth13/org-appear" :rev :newest)
  :hook (org-mode . org-appear-mode))

;; Transient menu of the org commands.
(use-package org-menu
  :vc (:url "https://github.com/sheijk/org-menu" :rev :newest)
  :commands org-menu
  :bind (:map org-mode-map ("C-c m" . org-menu)))

;; Side panel listing the tasks and the tree of the file.
(use-package org-sidebar
  :vc (:url "https://github.com/alphapapa/org-sidebar" :rev :newest)
  :commands (org-sidebar-tree org-sidebar-toggle))

;; --- Presentation -----------------------------------------------------------

(defun my-org-present-start ()
  "Switch the buffer to presentation mode."
  (org-present-big)
  (org-display-inline-images)
  (org-present-hide-cursor)
  (org-present-read-only))

(defun my-org-present-stop ()
  "Return to normal editing after a presentation."
  (org-present-small)
  (org-remove-inline-images)
  (org-present-show-cursor)
  (org-present-read-write))

(use-package org-present
  :ensure t
  :commands org-present
  :hook ((org-present-mode . my-org-present-start)
         (org-present-mode-quit . my-org-present-stop)))

;; --- Roam and journal -------------------------------------------------------

;; Automatic commit of the note files, enabled by a local variable set in the
;; templates below.
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
  ;; `org-roam-mode' is not a global mode: it is the major mode of the
  ;; backlinks buffer. Enabling it from `after-init', as was the case, had no
  ;; useful effect. Database synchronization is handled by
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
  ;; Do not carry the TODOs over to the next day.
  (org-journal-carryover-items "")
  (org-journal-date-format "%A, %d %B %Y"))

;; Recipe import from a URL, used by the "R" capture template.
(use-package org-chef
  :ensure t
  :commands (org-chef-get-recipe-from-url org-chef-insert-recipe))

(provide 'conf-org)

;;; conf-org ends here
